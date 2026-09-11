#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#define PCI_CFG_PATH "/sys/bus/pci/devices/0000:00:00.0/config"
#define DEV_MEM_PATH "/dev/mem"
#define MSR_PATH     "/dev/cpu/0/msr"

#define R_SA_MCHBAR              0x48
#define MCHBAR_ENABLE            UINT64_C(1)
#define MCHBAR_ADDR_MASK         UINT64_C(0xfffffffffffffffe)

#define PCODE_MAILBOX_DATA       0x5DA0
#define PCODE_MAILBOX_INTERFACE  0x5DA4
#define PCODE_RUN_BUSY           UINT32_C(0x80000000)

#define OC_INTERFACE_CMD         0x37
#define OC_READ_UVP_SUBCMD       0x16
#define OC_WRITE_UVP_SUBCMD      0x17

#define MSR_OVERCLOCKING_STATUS  UINT64_C(0x195)
#define UVP_STATUS_BIT           1

#define MAILBOX_TIMEOUT_US       100000
#define POLL_US                  50

struct mmio_map {
    int fd;
    void *map;
    size_t map_len;
    off_t map_phys;
    volatile uint32_t *data;
    volatile uint32_t *iface;
};

static void die(const char *what)
{
    fprintf(stderr, "ERROR: %s: %s\n", what, strerror(errno));
    exit(EXIT_FAILURE);
}

static uint64_t monotonic_us(void)
{
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0)
        die("clock_gettime");
    return (uint64_t)ts.tv_sec * UINT64_C(1000000) + (uint64_t)ts.tv_nsec / 1000;
}

static uint64_t read_mchbar_raw(void)
{
    int fd = open(PCI_CFG_PATH, O_RDONLY | O_CLOEXEC);
    if (fd < 0)
        die("open PCI host bridge config");

    uint64_t v = 0;
    ssize_t n = pread(fd, &v, sizeof(v), R_SA_MCHBAR);
    int saved = errno;
    close(fd);
    errno = saved;
    if (n != (ssize_t)sizeof(v)) {
        if (n >= 0) errno = EIO;
        die("read MCHBAR from PCI config offset 0x48");
    }
    return v;
}

static uint64_t read_msr(uint64_t msr)
{
    int fd = open(MSR_PATH, O_RDONLY | O_CLOEXEC);
    if (fd < 0)
        die("open /dev/cpu/0/msr (try: sudo modprobe msr)");

    uint64_t v = 0;
    ssize_t n = pread(fd, &v, sizeof(v), (off_t)msr);
    int saved = errno;
    close(fd);
    errno = saved;
    if (n != (ssize_t)sizeof(v)) {
        if (n >= 0) errno = EIO;
        die("read MSR 0x195");
    }
    return v;
}

static void map_mailbox(struct mmio_map *m, uint64_t mchbar)
{
    memset(m, 0, sizeof(*m));
    m->fd = -1;

    const long page_size = sysconf(_SC_PAGESIZE);
    if (page_size <= 0) {
        errno = EINVAL;
        die("sysconf(_SC_PAGESIZE)");
    }

    const uint64_t data_phys = mchbar + PCODE_MAILBOX_DATA;
    const uint64_t iface_phys = mchbar + PCODE_MAILBOX_INTERFACE;
    const uint64_t first = data_phys & ~((uint64_t)page_size - 1u);
    const uint64_t last = (iface_phys + sizeof(uint32_t) + (uint64_t)page_size - 1u) & ~((uint64_t)page_size - 1u);

    if (last <= first || last - first > (uint64_t)page_size * 2u) {
        errno = EOVERFLOW;
        die("invalid MCHBAR mapping range");
    }

    m->map_phys = (off_t)first;
    m->map_len = (size_t)(last - first);
    m->fd = open(DEV_MEM_PATH, O_RDWR | O_SYNC | O_CLOEXEC);
    if (m->fd < 0)
        die("open /dev/mem");

    m->map = mmap(NULL, m->map_len, PROT_READ | PROT_WRITE, MAP_SHARED, m->fd, m->map_phys);
    if (m->map == MAP_FAILED)
        die("mmap MCHBAR via /dev/mem");

    m->data = (volatile uint32_t *)((uint8_t *)m->map + (data_phys - first));
    m->iface = (volatile uint32_t *)((uint8_t *)m->map + (iface_phys - first));
}

static void unmap_mailbox(struct mmio_map *m)
{
    if (m->map && m->map != MAP_FAILED)
        munmap(m->map, m->map_len);
    if (m->fd >= 0)
        close(m->fd);
}

static uint32_t mmio_read32(volatile uint32_t *p)
{
    uint32_t v = *p;
    __sync_synchronize();
    return v;
}

static void mmio_write32(volatile uint32_t *p, uint32_t v)
{
    __sync_synchronize();
    *p = v;
    __sync_synchronize();
}

static int wait_idle(struct mmio_map *m, uint32_t *iface_out)
{
    const uint64_t deadline = monotonic_us() + MAILBOX_TIMEOUT_US;
    uint32_t iface;

    do {
        iface = mmio_read32(m->iface);
        if ((iface & PCODE_RUN_BUSY) == 0) {
            if (iface_out) *iface_out = iface;
            return 0;
        }
        usleep(POLL_US);
    } while (monotonic_us() < deadline);

    if (iface_out) *iface_out = iface;
    return -ETIMEDOUT;
}

static uint32_t make_cmd(uint8_t command, uint8_t param1, uint16_t param2)
{
    return PCODE_RUN_BUSY |
           (((uint32_t)param2 & 0x1fffu) << 16) |
           ((uint32_t)param1 << 8) |
           (uint32_t)command;
}

static int pcode_transaction(struct mmio_map *m,
                             uint8_t command,
                             uint8_t param1,
                             uint16_t param2,
                             uint32_t write_data,
                             uint32_t *read_data,
                             uint32_t *final_iface)
{
    uint32_t iface = 0;
    int rc = wait_idle(m, &iface);
    if (rc != 0) {
        fprintf(stderr, "ERROR: mailbox was busy before command (IFACE=0x%08x)\n", iface);
        return rc;
    }

    mmio_write32(m->data, write_data);
    mmio_write32(m->iface, make_cmd(command, param1, param2));

    rc = wait_idle(m, &iface);
    if (rc != 0) {
        fprintf(stderr, "ERROR: mailbox timed out (IFACE=0x%08x)\n", iface);
        return rc;
    }

    if (read_data) *read_data = mmio_read32(m->data);
    if (final_iface) *final_iface = iface;
    return 0;
}

static int pcode_read_uvp(struct mmio_map *m, uint32_t *uvp_raw, uint32_t *iface)
{
    uint32_t data = 0;
    int rc = pcode_transaction(m, OC_INTERFACE_CMD, OC_READ_UVP_SUBCMD, 0, 0, &data, iface);
    if (rc == 0 && uvp_raw)
        *uvp_raw = data;
    return rc;
}

static int pcode_write_uvp_off(struct mmio_map *m, uint32_t *reply, uint32_t *iface)
{
    /* Deliberately hard-coded: this utility can only request UVP=0. */
    return pcode_transaction(m, OC_INTERFACE_CMD, OC_WRITE_UVP_SUBCMD, 0, 0, reply, iface);
}

static void print_status_line(const char *label, uint32_t data, uint32_t iface)
{
    printf("%s: DATA=0x%08x  IFACE=0x%08x  decoded_UVP=%u\n",
           label, data, iface, data & 0x3u);
}

static void usage(const char *argv0)
{
    fprintf(stderr,
        "Usage:\n"
        "  sudo %s status\n"
        "  sudo %s disable-test --yes\n\n"
        "status       : READ ONLY. Reads PCODE UVP and MSR 0x195.\n"
        "disable-test : Sends only OC interface 0x37 / subcommand 0x17 / data 0,\n"
        "               then reads UVP and MSR 0x195 back. No voltage offset is written.\n",
        argv0, argv0);
}

int main(int argc, char **argv)
{
    if (geteuid() != 0) {
        fprintf(stderr, "ERROR: run as root.\n");
        return EXIT_FAILURE;
    }

    bool do_write = false;
    if (argc == 2 && strcmp(argv[1], "status") == 0) {
        do_write = false;
    } else if (argc == 3 && strcmp(argv[1], "disable-test") == 0 && strcmp(argv[2], "--yes") == 0) {
        do_write = true;
    } else {
        usage(argv[0]);
        return EXIT_FAILURE;
    }

    uint64_t mchbar_raw = read_mchbar_raw();
    if ((mchbar_raw & MCHBAR_ENABLE) == 0) {
        fprintf(stderr, "ERROR: MCHBAR enable bit is clear (raw=0x%016" PRIx64 ").\n", mchbar_raw);
        return EXIT_FAILURE;
    }

    uint64_t mchbar = mchbar_raw & MCHBAR_ADDR_MASK;
    if (mchbar == 0 || (mchbar & 0xfffu) != 0) {
        fprintf(stderr, "ERROR: implausible MCHBAR base 0x%016" PRIx64 " (raw 0x%016" PRIx64 ").\n",
                mchbar, mchbar_raw);
        return EXIT_FAILURE;
    }

    printf("MCHBAR raw : 0x%016" PRIx64 "\n", mchbar_raw);
    printf("MCHBAR base: 0x%016" PRIx64 "\n", mchbar);
    printf("PCODE DATA : 0x%016" PRIx64 "\n", mchbar + PCODE_MAILBOX_DATA);
    printf("PCODE IFACE: 0x%016" PRIx64 "\n", mchbar + PCODE_MAILBOX_INTERFACE);

    uint64_t msr_before = read_msr(MSR_OVERCLOCKING_STATUS);
    printf("MSR 0x195 before: 0x%016" PRIx64 "  UVP(bit1)=%u\n",
           msr_before, (unsigned)((msr_before >> UVP_STATUS_BIT) & 1u));

    struct mmio_map m;
    map_mailbox(&m, mchbar);

    uint32_t data = 0, iface = 0;
    int rc = pcode_read_uvp(&m, &data, &iface);
    if (rc != 0) {
        unmap_mailbox(&m);
        fprintf(stderr, "PCODE UVP read failed: %s\n", strerror(-rc));
        return EXIT_FAILURE;
    }
    print_status_line("PCODE UVP before", data, iface);

    if (!do_write) {
        unmap_mailbox(&m);
        puts("READ-ONLY status complete. No mailbox write was issued.");
        return EXIT_SUCCESS;
    }

    puts("\nRequesting UVP=0 via PCODE OC interface 0x37, subcommand 0x17 ...");
    uint32_t reply = 0, write_iface = 0;
    rc = pcode_write_uvp_off(&m, &reply, &write_iface);
    if (rc != 0) {
        unmap_mailbox(&m);
        fprintf(stderr, "PCODE UVP=0 request failed: %s\n", strerror(-rc));
        return EXIT_FAILURE;
    }
    printf("PCODE write reply: DATA=0x%08x  IFACE=0x%08x\n", reply, write_iface);

    usleep(1000);
    uint32_t after_data = 0, after_iface = 0;
    rc = pcode_read_uvp(&m, &after_data, &after_iface);
    unmap_mailbox(&m);
    if (rc != 0) {
        fprintf(stderr, "PCODE UVP post-read failed: %s\n", strerror(-rc));
        return EXIT_FAILURE;
    }
    print_status_line("PCODE UVP after ", after_data, after_iface);

    uint64_t msr_after = read_msr(MSR_OVERCLOCKING_STATUS);
    printf("MSR 0x195 after : 0x%016" PRIx64 "  UVP(bit1)=%u\n",
           msr_after, (unsigned)((msr_after >> UVP_STATUS_BIT) & 1u));

    const unsigned before = (unsigned)((msr_before >> UVP_STATUS_BIT) & 1u);
    const unsigned after = (unsigned)((msr_after >> UVP_STATUS_BIT) & 1u);

    puts("");
    if (after == 0) {
        puts("RESULT: UVP bit is CLEAR. This is the proof needed before designing a boot-time hook.");
        puts("No undervolt was applied by this utility.");
        return EXIT_SUCCESS;
    }

    if (before == 1 && after == 1) {
        puts("RESULT: UVP stayed SET. Do NOT flash a ROM that merely changes the FSPM_UPD default byte;");
        puts("that byte is already 0 in KLS71 and this CPU/firmware path did not clear runtime UVP.");
        return 2;
    }

    puts("RESULT: UVP state did not produce the expected transition; treat as inconclusive.");
    return 3;
}
