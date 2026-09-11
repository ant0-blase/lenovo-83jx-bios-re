# UEFI Shell scripts

These scripts target only the tested Lenovo Yoga Slim 7 14ILL10 / 83JX `KLS71` `CpuSetup` layout. Revalidate the IFR/varstore offsets after a BIOS update before reusing them.

## Active performance scripts

`Yoga14ILL10-Performance.nsh` applies the clean CPU baseline while keeping normal CPU power management intact:

```text
C-states                 enabled
C1E                      enabled
Turbo                    enabled
Energy Efficient P-state enabled
Base Power Boot Mode     Nominal
Timed MWAIT              disabled
IO MWAIT Redirection     disabled
Package C-State Limit    Auto
PSYS PMax                Auto
Acoustic mitigation      disabled
Core/GT/ATOM slow slew   fastest exposed value
cTDP/Assured Power init  normal
```

`Yoga14ILL10-Battery37W-BCLK.nsh` applies the current maximum-performance battery/BCLK profile:

```text
BCLK Spread              off
ThETA Ibatt              off
VrAlert Demotion         off
Package PL1              37 W
Platform PL1             37 W
Platform PL2             37 W
PACKAGE_POWER_LIMIT lock off
PSYS PMax                Auto
Base Power mode          Nominal
cTDP init                normal
PL4 Boost                63 W (IFR maximum; aggressive experiment)
```

After **Load Setup Defaults**:

```text
Yoga14ILL10-Performance.nsh
Yoga14ILL10-Battery37W-BCLK.nsh
```

Then fully power the machine off and cold boot.

`Yoga14ILL10-Battery37W-BCLK-rollback.nsh` restores the fields owned by the battery/BCLK profile to their reference/default state without undoing the performance baseline.

## Audit

`Yoga14ILL10-Audit-current.nsh` reads the active performance, battery, BCLK and power fields. It performs no writes.

## Active undervolt research

`Yoga14ILL10-Undervolt-OC-Lock.nsh` changes only:

```text
CpuSetup +0xFA = 0
```

That has been verified to clear the observed normal OC Lock state, but **UVP remains active** and no voltage offset is applied by this script.

`Yoga14ILL10-UVP-PCODE0A-audit.nsh` is the remaining read-only early-policy audit. It reads the hidden `CpuSetup +0x2F3/+0x2F4/+0x2F5` candidates feeding the early internal policy/PCODE `0x0A` path plus the known OC/run-control fields. It does not write the unnamed bytes.

The older UEFI/BDS/raw-PCODE timing experiments are no longer kept as active files because they already established that those timings are too late; their results are documented in `../docs/UNDERVOLT-REVERSE.md`.

## Safety boundary

The active scripts do **not** disable PROCHOT, Thermal Monitor, VR thermal alerts, ICCMAX, TDC, Fast Vmode, load-line/voltage protections or raw EC/BMS protections. The 63 W PL4-Boost value can nevertheless increase peak battery/VR stress and droop risk.
