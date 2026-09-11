# lnl-uvp-pcode

Conservative Linux probe for the Intel PCODE OC mailbox on the Lenovo Yoga Slim 7 14ILL10 / 83JX (Lunar Lake).

It does **not** flash firmware and it does **not** apply a voltage offset.

The tool is intentionally limited to:

- reading MCHBAR from PCI 0000:00:00.0 offset 0x48;
- reading PCODE UnderVoltProtection through OC interface `0x37`, subcommand `0x16`;
- optionally requesting `UnderVoltProtection = 0` through subcommand `0x17` with data `0`;
- reading `IA32_OVERCLOCKING_STATUS` (`MSR 0x195`) before and after.

There is no arbitrary mailbox command mode and no UVP-enable command.

## Build

```bash
make
sudo modprobe msr
```

## First run: read-only

```bash
sudo ./lnl-uvp-pcode status
```

This must complete before trying the write test. It does not issue any write command.

## One-shot UVP-off test

```bash
sudo ./lnl-uvp-pcode disable-test --yes
```

This requests UVP=0 only. It then reads the PCODE state and `MSR 0x195` back.

Interpretation:

- `MSR 0x195 ... UVP(bit1)=0`: the runtime UVP control accepted the disable request; a boot-time implementation is worth pursuing.
- `UVP(bit1)=1`: the request was ignored/rejected or a lower firmware/p-code policy keeps UVP active. Do not flash a ROM that only changes the static `FSPM_UPD` byte; KLS71 already stores that byte as zero.

If `/dev/mem` mapping is denied, stop. Do not weaken kernel security settings merely to force the test; use a UEFI-side implementation instead.
