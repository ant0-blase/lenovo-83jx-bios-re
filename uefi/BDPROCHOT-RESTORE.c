typedef unsigned long long EFI_STATUS;
typedef unsigned int UINT32;

#define MSR_POWER_CTL 0x1FCu
#define ENABLE_BIDIR_PROCHOT 0x1u

static inline void rdmsr(UINT32 msr, UINT32 *lo, UINT32 *hi)
{
    __asm__ __volatile__("rdmsr" : "=a"(*lo), "=d"(*hi) : "c"(msr));
}

static inline void wrmsr(UINT32 msr, UINT32 lo, UINT32 hi)
{
    __asm__ __volatile__("wrmsr" : : "c"(msr), "a"(lo), "d"(hi));
}

__attribute__((ms_abi))
EFI_STATUS efi_main(void *image_handle, void *system_table)
{
    UINT32 lo, hi;
    (void)image_handle;
    (void)system_table;

    rdmsr(MSR_POWER_CTL, &lo, &hi);
    lo |= ENABLE_BIDIR_PROCHOT;
    wrmsr(MSR_POWER_CTL, lo, hi);
    rdmsr(MSR_POWER_CTL, &lo, &hi);

    return (lo & ENABLE_BIDIR_PROCHOT) ? 0u : 1u;
}
