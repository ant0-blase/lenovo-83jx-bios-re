# Lenovo 83JX BIOS / UEFI Reverse Engineering

Reverse engineering and performance research for the **Lenovo Yoga Slim 7 14ILL10 (machine type 83JX)** based on Intel **Lunar Lake / Core Ultra 200V**.

This repository keeps only the parts that are still useful today: the consolidated BIOS reverse map, the working performance/37 W scripts, the active undervolt/UVP research, and the small set of tools needed to continue that work.

> Machine-specific research only. No proprietary Lenovo firmware image is redistributed.

## Target

| Item | Value |
|---|---|
| Laptop | Lenovo Yoga Slim 7 14ILL10 |
| Machine type | `83JX` |
| Platform | Intel Lunar Lake / Core Ultra 200V |
| Tested CPU | Intel Core Ultra 7 258V |
| Analyzed image | `KLS71_sign.rom` |
| ROM SHA256 | `21ff6995dc89ee637aceba0f0c37aa9b3b04292d04b8fe7240e512a7874c86bd` |
| Hidden varstore | `CpuSetup` |
| VarStoreId | `0x3` |
| GUID | `75E3088B-88BB-490F-AA29-FAA83244E8E3` |
| Size | `0x458` bytes |

## Current status

| Area | Status |
|---|---|
| Hidden `CpuSetup` IFR | **187 recovered entries** in `docs/cpusetup-variables.csv` |
| Performance profile | Working clean UEFI profile |
| BCLK spread | `CpuSetup + 0x232`; tested disabled |
| Package / platform power | Explicit 37 W PL1/PL2 profile |
| Battery EDP clamp | Reactive PL4 / RSOC path strongly supported; PL4 Boost is causal |
| Undervolt OC lock | `CpuSetup + 0xFA` verified to clear the observed OC lock |
| Undervolt utility | MSR `0x150` tool implemented for Core/IA + Ring/Cache |
| Undervolt Protection | **Still active**; runtime/pre-OS disable requests are locked |
| FSP-M UVP path | `LNLUPD_M -> internal policy -> SiInitPreMemFsp/PCODE` recovered |
| Exact UVP firmware fix | **Still in progress** |

The undervolt groundwork is therefore ready, but actual voltage writes are intentionally blocked by the tool while `IA32_OVERCLOCKING_STATUS.UVP` remains set.

## Repository layout

```text
.
├── README.md
├── GITHUB-METADATA.md
├── docs/
│   ├── BIOS-REVERSE-MAP.md
│   ├── BATTERY-EDP-REVERSE.md
│   ├── UNDERVOLT-REVERSE.md
│   └── cpusetup-variables.csv
├── uefi/
│   ├── README.md
│   ├── Yoga14ILL10-Audit-current.nsh
│   ├── Yoga14ILL10-Performance.nsh
│   ├── Yoga14ILL10-Battery37W-BCLK.nsh
│   ├── Yoga14ILL10-Battery37W-BCLK-rollback.nsh
│   ├── Yoga14ILL10-Undervolt-OC-Lock.nsh
│   └── Yoga14ILL10-UVP-PCODE0A-audit.nsh
└── tools/
    ├── analyze-lnl-fspm-uvp/
    ├── lnl-undervolt/
    └── lnl-uvp-pcode/
```

Old one-shot diagnostics, failed EDP workarounds, generated EFI binaries, trace scripts and duplicated experiment notes are deliberately not kept in the active tree. Their useful conclusions are consolidated in the three reverse documents above.

## Performance profile

After **Load Setup Defaults** on the same tested firmware revision:

```text
Yoga14ILL10-Performance.nsh
Yoga14ILL10-Battery37W-BCLK.nsh
```

Then fully power the machine off and cold boot.

The active battery/BCLK profile currently uses:

```text
BCLK Spread              OFF
ThETA Ibatt              OFF
VrAlert Demotion         OFF
Package PL1              37 W
Platform PL1             37 W
Platform PL2             37 W
PACKAGE_POWER_LIMIT lock OFF
PSYS PMax                AUTO
Base Power Boot Mode     Nominal
cTDP / Assured Power     normal initialization
PL4 Boost                63 W (IFR maximum, aggressive experiment)
```

`PL4 Boost = 7.5 W` was the first value directly observed to remove the persistent below-80% EDP state. The current 63 W value is the maximum exposed by the recovered IFR and is kept as the current maximum-headroom experiment; it is **not** claimed to be necessary or optimal.

## Reverse-engineering highlights

- `CpuSetup + 0xFA` is the recovered **Overclocking Lock**. Clearing it changes the observed OC-lock state but does not clear UVP.
- Runtime state can be `OC Lock=0`, `OC Secure=0`, `UVP=1`, proving those controls are distinct on this platform.
- MCHBAR is obtained from PCI `00:00.0 + 0x48`; the PCODE mailbox used here is at `MCHBAR + 0x5DA0/+0x5DA4`.
- PCODE OC interface `0x37`, subcommand `0x16` reads UVP and `0x17 DATA=0` requests UVP off. The write is already `PCODE_LOCKED` at runtime and by normal pre-OS timings tested so far.
- `SiInitPreMemFsp` contains an early raw PCODE `0x48` path controlled by internal `UnderVoltProtection` policy.
- Two real `LNLUPD_M` structures exist at ROM offsets `0x00D56764` and `0x01156764`.
- `FSPM + 0x896` maps to internal policy `+0x13B`, but the static value is already `0` while runtime UVP is `1`, so simply patching that byte is not a valid solution.
- `FSPM +0x886/+0x887/+0x888` map to internal `+0xF9/+0xFA/+0xFB`, which are packed into early PCODE command `0x0A`.
- The battery transition around 80→79% was package-wide: `MSR 0x64F` moved from `...0800` to persistent `...0100` without corresponding HWP or visible RAPL changes.
- `CpuSetup + 0x2C` (`Power Limit 4 Boost`) is the first setting that causally changed that EDP behavior.

## Documentation

Start with `docs/BIOS-REVERSE-MAP.md` for the full recovered BIOS map, including firmware modules, live MSRs, VR/current controls, rails, FSP-M transfer and every known `CpuSetup` offset.

Use `docs/BATTERY-EDP-REVERSE.md` for the complete battery/EDP/Reactive-PL4 investigation and the failed paths already ruled out. Use `docs/UNDERVOLT-REVERSE.md` for the OC-lock, UVP, PCODE, FSP-M and MSR `0x150` work that is still ongoing.

## Safety boundary

The active performance scripts do **not** disable PROCHOT, Thermal Monitor, VR thermal alert, ICCMAX, TDC, Fast Vmode, load-line protection or raw EC/BMS protection. The 63 W PL4-Boost setting can still increase transient battery/VR current, droop and shutdown risk.

Do not reuse these offsets on another machine or BIOS revision without re-extracting the IFR and verifying the varstore layout.

## Contributing

Useful contributions are exact IFR extracts, disassembly references, repeatable live traces and corrections that clearly distinguish **confirmed**, **observed**, **inferred** and **unknown** behavior. Do not submit Lenovo firmware binaries.
