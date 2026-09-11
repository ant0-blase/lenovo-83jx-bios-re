#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <cpuid.h>

#define MSR_OC_MAILBOX             0x150u
#define MSR_ARCH_CAPABILITIES      0x10Au
#define MSR_OC_MISC_CTRL           0x194u
#define MSR_OVERCLOCKING_STATUS    0x195u

#define OC_MAILBOX_BUSY            (1ULL << 63)
#define OC_CMD_READ_VF             0x10u
#define OC_CMD_WRITE_VF            0x11u
#define OC_LOCK_BIT                20u
#define UVP_STATUS_BIT             1u
#define OC_SECURE_STATUS_BIT       2u
#define OC_UTILIZED_STATUS_BIT     0u
#define ARCH_CAP_OC_STATUS_BIT     23u

/*
 * Intel OC mailbox voltage offset format used by existing Intel undervolt tools:
 * [63]    busy/run
 * [47:40] domain / voltage plane
 * [39:32] command (0x10 read, 0x11 write)
 * [31:21] signed 11-bit voltage offset in 1/1024 V units
 */

struct msr_dev {
    int fd;
    int cpu;
};

struct plane_name {
    const char *name;
    int id;
};

static const struct plane_name planes[] = {
    {"core", 0},
    {"ia", 0},
    {"gt", 1},
    {"gpu", 1},
    {"ring", 2},
    {"cache", 2},
    {"uncore", 3},
    {"analogio", 4},
    {"digitalio", 5},
};

static void die(const char *msg)
{
    perror(msg);
    exit(EXIT_FAILURE);
}

static void usage(const char *argv0)
{
    fprintf(stderr,
        "Usage:\n"
        "  %s [--cpu N] status\n"
        "  %s [--cpu N] read <core|gt|ring|uncore|analogio|digitalio|0..5>\n"
        "  %s [--cpu N] encode <plane> <mV>\n"
        "  %s [--cpu N] set <plane> <mV>\n"
        "  %s [--cpu N] reset <plane>\n"
        "\n"
        "Safety policy:\n"
        "  - set is undervolt-only; Lunar Lake is capped to -100 .. 0 mV.\n"
        "  - set refuses while IA32_OVERCLOCKING_STATUS.UVP=1.\n"
        "  - set refuses while MSR 0x194 bit20 (OC Lock) is set.\n"
        "  - the offset is read back after programming.\n",
        argv0, argv0, argv0, argv0, argv0);
}

static int open_msr(struct msr_dev *d, int cpu, bool write)
{
    char path[128];
    snprintf(path, sizeof(path), "/dev/cpu/%d/msr", cpu);
    int flags = write ? O_RDWR : O_RDONLY;
    d->fd = open(path, flags | O_CLOEXEC);
    d->cpu = cpu;
    return d->fd < 0 ? -errno : 0;
}

static void close_msr(struct msr_dev *d)
{
    if (d->fd >= 0) close(d->fd);
    d->fd = -1;
}

static int rdmsr64(struct msr_dev *d, uint32_t msr, uint64_t *val)
{
    ssize_t n = pread(d->fd, val, sizeof(*val), (off_t)msr);
    if (n == (ssize_t)sizeof(*val)) return 0;
    return n < 0 ? -errno : -EIO;
}

static int wrmsr64(struct msr_dev *d, uint32_t msr, uint64_t val)
{
    ssize_t n = pwrite(d->fd, &val, sizeof(val), (off_t)msr);
    if (n == (ssize_t)sizeof(val)) return 0;
    return n < 0 ? -errno : -EIO;
}

static int parse_plane(const char *s)
{
    char *end = NULL;
    errno = 0;
    long v = strtol(s, &end, 0);
    if (!errno && end && *end == '\0' && v >= 0 && v <= 5)
        return (int)v;

    for (size_t i = 0; i < sizeof(planes)/sizeof(planes[0]); ++i)
        if (strcasecmp(s, planes[i].name) == 0)
            return planes[i].id;
    return -1;
}

static unsigned intel_family_model(unsigned *family_out)
{
    unsigned eax=0, ebx=0, ecx=0, edx=0;
    if (!__get_cpuid(1, &eax, &ebx, &ecx, &edx)) {
        if (family_out) *family_out = 0;
        return 0;
    }
    unsigned fam = (eax >> 8) & 0xf;
    unsigned mod = (eax >> 4) & 0xf;
    unsigned extfam = (eax >> 20) & 0xff;
    unsigned extmod = (eax >> 16) & 0xf;
    if (fam == 0xf) fam += extfam;
    if (fam == 0x6 || fam == 0xf) mod |= extmod << 4;
    if (family_out) *family_out = fam;
    return mod;
}

static const char *canonical_plane_name(int plane)
{
    switch (plane) {
        case 0: return "Core/IA";
        case 1: return "Plane 1 (legacy GT; LNL semantics unverified)";
        case 2: return "Ring/Cache";
        case 3: return "Uncore";
        case 4: return "Analog I/O";
        case 5: return "Digital I/O";
        default: return "Unknown";
    }
}

static int16_t sign_extend_11(uint16_t x)
{
    x &= 0x7ffu;
    if (x & 0x400u)
        return (int16_t)(x | 0xf800u);
    return (int16_t)x;
}

static double raw_to_mv(uint16_t raw)
{
    return (double)sign_extend_11(raw) * (1000.0 / 1024.0);
}

static uint16_t mv_to_raw(double mv, int *signed_units_out)
{
    /* nearest 1/1024 V step */
    long units = lround(mv * 1024.0 / 1000.0);
    if (units < -1024) units = -1024;
    if (units >  1023) units =  1023;
    if (signed_units_out) *signed_units_out = (int)units;
    return (uint16_t)((uint32_t)units & 0x7ffu);
}

static uint64_t make_vf_command(int plane, uint8_t cmd, uint16_t raw)
{
    return OC_MAILBOX_BUSY |
           ((uint64_t)(plane & 0xff) << 40) |
           ((uint64_t)cmd << 32) |
           ((uint64_t)(raw & 0x7ffu) << 21);
}

static int mailbox_wait(struct msr_dev *d, uint64_t *last)
{
    /* Most implementations need only a few microseconds. Give PCODE 20 ms. */
    for (int i = 0; i < 2000; ++i) {
        uint64_t v = 0;
        int rc = rdmsr64(d, MSR_OC_MAILBOX, &v);
        if (rc) return rc;
        if (last) *last = v;
        if (!(v & OC_MAILBOX_BUSY)) return 0;
        usleep(10);
    }
    return -ETIMEDOUT;
}

static int mailbox_read_offset(struct msr_dev *d, int plane, uint64_t *response, double *mv)
{
    uint64_t cmd = make_vf_command(plane, OC_CMD_READ_VF, 0);
    int rc = wrmsr64(d, MSR_OC_MAILBOX, cmd);
    if (rc) return rc;

    uint64_t r = 0;
    rc = mailbox_wait(d, &r);
    if (rc) return rc;

    uint16_t raw = (uint16_t)((r >> 21) & 0x7ffu);
    if (response) *response = r;
    if (mv) *mv = raw_to_mv(raw);
    return 0;
}

static int read_security_state(struct msr_dev *d,
                               uint64_t *arch, uint64_t *oc194, uint64_t *st195)
{
    int rc;
    if ((rc = rdmsr64(d, MSR_ARCH_CAPABILITIES, arch))) return rc;
    if ((rc = rdmsr64(d, MSR_OC_MISC_CTRL, oc194))) return rc;
    if ((rc = rdmsr64(d, MSR_OVERCLOCKING_STATUS, st195))) return rc;
    return 0;
}

static void print_status(struct msr_dev *d)
{
    uint64_t a = 0, m194 = 0, m195 = 0;
    int rc = read_security_state(d, &a, &m194, &m195);
    if (rc) {
        errno = -rc;
        die("reading status MSRs");
    }

    unsigned fam = 0;
    unsigned model = intel_family_model(&fam);
    printf("CPU %d, CPUID family %u model 0x%02x%s\n", d->cpu, fam, model,
           (fam == 6 && model == 0xBD) ? " (Lunar Lake)" : "");
    printf("IA32_ARCH_CAPABILITIES (0x10A): 0x%016" PRIx64 "\n", a);
    printf("  OC status MSR advertised (bit23): %u\n", (unsigned)((a >> ARCH_CAP_OC_STATUS_BIT) & 1));
    printf("MSR 0x194:                       0x%016" PRIx64 "\n", m194);
    printf("  OC Lock (observed bit20):        %u\n", (unsigned)((m194 >> OC_LOCK_BIT) & 1));
    printf("IA32_OVERCLOCKING_STATUS 0x195: 0x%016" PRIx64 "\n", m195);
    printf("  OC utilized (bit0):              %u\n", (unsigned)((m195 >> OC_UTILIZED_STATUS_BIT) & 1));
    printf("  Undervolt Protection (bit1):     %u\n", (unsigned)((m195 >> UVP_STATUS_BIT) & 1));
    printf("  OC Secure Status (bit2):         %u\n", (unsigned)((m195 >> OC_SECURE_STATUS_BIT) & 1));

    if ((m195 >> UVP_STATUS_BIT) & 1)
        printf("\nRESULT: runtime undervolt is firmware/microcode blocked (UVP=1).\n");
    else if ((m194 >> OC_LOCK_BIT) & 1)
        printf("\nRESULT: runtime undervolt is blocked by OC Lock.\n");
    else
        printf("\nRESULT: firmware locks required by this tool are clear. Mailbox can be tested.\n");
}

static int do_read(struct msr_dev *d, int plane, bool verbose)
{
    uint64_t response = 0;
    double mv = 0.0;
    int rc = mailbox_read_offset(d, plane, &response, &mv);
    if (rc) return rc;

    uint16_t raw = (uint16_t)((response >> 21) & 0x7ffu);
    printf("%s plane %d: response=0x%016" PRIx64 ", raw=0x%03x, offset=%+.3f mV\n",
           canonical_plane_name(plane), plane, response, raw, mv);

    if (verbose && response == 0)
        printf("note: all-zero response is ambiguous: it can mean 0 mV, a blocked/ignored mailbox, or an unsupported command on this CPU.\n");
    return 0;
}

static int do_set(struct msr_dev *d, int plane, double requested_mv)
{
    unsigned family = 0;
    unsigned model = intel_family_model(&family);
    const bool lunar_lake = (family == 6 && model == 0xBD);

    /* Lenovo LNL firmware explicitly documents Param1 0=Core and 2=Ring
     * for the VF mailbox path. Do not guess the remaining legacy plane IDs
     * on production Lunar Lake. */
    if (lunar_lake && plane != 0 && plane != 2) {
        fprintf(stderr,
            "REFUSED: CPUID family 6 model 0xBD (Lunar Lake); write semantics for plane %d are not proven.\n"
            "This build permits writes only to Core/IA (0) and Ring/Cache (2) on LNL.\n", plane);
        return -EOPNOTSUPP;
    }
    if (requested_mv > 0.0001) {
        fprintf(stderr, "Refusing positive voltage offset: this tool is undervolt-only.\n");
        return -EINVAL;
    }
    const double hard_limit = lunar_lake ? -100.0 : -250.0;
    if (requested_mv < hard_limit) {
        fprintf(stderr, "Refusing %.3f mV: hard safety limit on this CPU is %.0f mV.\n", requested_mv, hard_limit);
        return -ERANGE;
    }

    uint64_t a = 0, m194 = 0, m195 = 0;
    int rc = read_security_state(d, &a, &m194, &m195);
    if (rc) return rc;

    if ((m195 >> UVP_STATUS_BIT) & 1) {
        fprintf(stderr,
            "REFUSED: IA32_OVERCLOCKING_STATUS=0x%" PRIx64 " has UVP(bit1)=1.\n"
            "Disable UnderVoltProtection during firmware/FSP init first.\n", m195);
        return -EPERM;
    }
    if ((m194 >> OC_LOCK_BIT) & 1) {
        fprintf(stderr,
            "REFUSED: MSR 0x194=0x%" PRIx64 " has OC Lock(bit20)=1.\n", m194);
        return -EPERM;
    }

    int units = 0;
    uint16_t raw = mv_to_raw(requested_mv, &units);
    double programmed_mv = (double)units * (1000.0 / 1024.0);
    uint64_t cmd = make_vf_command(plane, OC_CMD_WRITE_VF, raw);

    printf("Programming %s plane %d: requested=%+.3f mV, encoded=%d/1024 V (%+.3f mV)\n",
           canonical_plane_name(plane), plane, requested_mv, units, programmed_mv);
    printf("MSR 0x150 write command: 0x%016" PRIx64 "\n", cmd);

    rc = wrmsr64(d, MSR_OC_MAILBOX, cmd);
    if (rc) return rc;

    uint64_t write_response = 0;
    rc = mailbox_wait(d, &write_response);
    if (rc) return rc;

    /* Read it back through cmd 0x10; do not trust a successful WRMSR alone. */
    uint64_t read_response = 0;
    double actual_mv = 0.0;
    rc = mailbox_read_offset(d, plane, &read_response, &actual_mv);
    if (rc) return rc;

    uint16_t actual_raw = (uint16_t)((read_response >> 21) & 0x7ffu);
    int actual_units = sign_extend_11(actual_raw);

    printf("write response: 0x%016" PRIx64 "\n", write_response);
    printf("readback:       0x%016" PRIx64 " -> %+.3f mV\n", read_response, actual_mv);

    if (actual_units != units) {
        fprintf(stderr,
            "VERIFY FAILED: requested encoded units=%d, readback=%d.\n"
            "The CPU/firmware probably ignored or rejected the mailbox write.\n",
            units, actual_units);
        return -EIO;
    }

    printf("VERIFY OK: %s offset is now %+.3f mV.\n",
           canonical_plane_name(plane), actual_mv);
    return 0;
}

int main(int argc, char **argv)
{
    int cpu = 0;
    int argi = 1;

    if (argc > 3 && strcmp(argv[1], "--cpu") == 0) {
        char *end = NULL;
        long c = strtol(argv[2], &end, 10);
        if (!end || *end || c < 0 || c > 65535) {
            fprintf(stderr, "Invalid CPU: %s\n", argv[2]);
            return 2;
        }
        cpu = (int)c;
        argi = 3;
    }

    if (argi >= argc) {
        usage(argv[0]);
        return 2;
    }

    const char *action = argv[argi++];
    bool needs_write = strcmp(action, "status") != 0;

    /* encode does not need /dev/msr at all. */
    if (strcmp(action, "encode") == 0) {
        if (argi + 1 >= argc) { usage(argv[0]); return 2; }
        int plane = parse_plane(argv[argi++]);
        if (plane < 0) { fprintf(stderr, "Invalid plane.\n"); return 2; }
        char *end = NULL;
        double mv = strtod(argv[argi], &end);
        if (!end || *end) { fprintf(stderr, "Invalid mV value.\n"); return 2; }
        int units = 0;
        uint16_t raw = mv_to_raw(mv, &units);
        printf("plane=%d (%s) mV=%+.3f units=%d raw=0x%03x\n",
               plane, canonical_plane_name(plane), mv, units, raw);
        printf("read : 0x%016" PRIx64 "\n", make_vf_command(plane, OC_CMD_READ_VF, 0));
        printf("write: 0x%016" PRIx64 "\n", make_vf_command(plane, OC_CMD_WRITE_VF, raw));
        return 0;
    }

    struct msr_dev d = {.fd = -1, .cpu = cpu};
    int rc = open_msr(&d, cpu, needs_write);
    if (rc) {
        errno = -rc;
        fprintf(stderr, "Cannot open /dev/cpu/%d/msr: %s\n", cpu, strerror(errno));
        fprintf(stderr, "Try: sudo modprobe msr && sudo %s ...\n", argv[0]);
        return 1;
    }

    if (strcmp(action, "status") == 0) {
        print_status(&d);
        close_msr(&d);
        return 0;
    }

    if (strcmp(action, "read") == 0) {
        if (argi >= argc) { usage(argv[0]); close_msr(&d); return 2; }
        int plane = parse_plane(argv[argi]);
        if (plane < 0) { fprintf(stderr, "Invalid plane.\n"); close_msr(&d); return 2; }
        rc = do_read(&d, plane, true);
    } else if (strcmp(action, "set") == 0) {
        if (argi + 1 >= argc) { usage(argv[0]); close_msr(&d); return 2; }
        int plane = parse_plane(argv[argi++]);
        if (plane < 0) { fprintf(stderr, "Invalid plane.\n"); close_msr(&d); return 2; }
        char *end = NULL;
        double mv = strtod(argv[argi], &end);
        if (!end || *end) { fprintf(stderr, "Invalid mV value.\n"); close_msr(&d); return 2; }
        rc = do_set(&d, plane, mv);
    } else if (strcmp(action, "reset") == 0) {
        if (argi >= argc) { usage(argv[0]); close_msr(&d); return 2; }
        int plane = parse_plane(argv[argi]);
        if (plane < 0) { fprintf(stderr, "Invalid plane.\n"); close_msr(&d); return 2; }
        rc = do_set(&d, plane, 0.0);
    } else {
        usage(argv[0]);
        close_msr(&d);
        return 2;
    }

    if (rc) {
        int e = -rc;
        fprintf(stderr, "Operation failed: %s (%d)\n", strerror(e), e);
        close_msr(&d);
        return 1;
    }

    close_msr(&d);
    return 0;
}
