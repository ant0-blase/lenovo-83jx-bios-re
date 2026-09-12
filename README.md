# Lenovo 83JX BIOS / UEFI Reverse Engineering

Reverse engineering, power-management research and performance tuning for the **Lenovo Yoga Slim 7 14ILL10 (machine type 83JX)** based on Intel **Lunar Lake / Core Ultra 200V**.

The repository focuses on the parts that are still useful: the recovered firmware maps, the battery/EDP and undervolt research, one consolidated **PERFORMANCE MAX** profile, and the small set of tools used to continue the reverse engineering.

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
| `CpuSetup` VarStoreId | `0x3` |
| `CpuSetup` GUID | `75E3088B-88BB-490F-AA29-FAA83244E8E3` |
| `CpuSetup` size | `0x458` bytes |

## Current status

| Area | Status |
|---|---|
| Hidden `CpuSetup` IFR | **187 recovered entries** in `docs/cpusetup-variables.csv` |
| Additional firmware controls | `SaSetup` memory/GT and HWP/SpeedStep controls recovered from the exact KLS71 SetupUtility IFR |
| Performance profile | One consolidated UEFI profile: `Yoga14ILL10-PERFORMANCE-MAX.nsh` |
| Windows power policy | AC maximum-performance policy + DC battery-efficient HWP policy |
| Package / platform power | Explicit 37 W PL1/PL2 target |
| BCLK spread | `CpuSetup + 0x232`; tested disabled |
| Battery EDP clamp | Reactive PL4 path is causal; Windows-only ~8 W state was also affected by the Windows power policy |
| CPU / iGPU load-line tune | Experimental P-core + GT AC load-line at `2.50 mOhm` |
| Undervolt OC lock | `CpuSetup + 0xFA` verified to clear the observed OC lock |
| MSR voltage-offset path | Tooling implemented, but writes remain blocked while UVP is active |
| Undervolt Protection | **Still active**; runtime and tested pre-OS disable requests are locked |
| Exact UVP firmware fix | **Still in progress** |

## Repository layout

```text
.
├── docs/
│   ├── BATTERY-EDP-REVERSE.md
│   ├── BIOS-REVERSE-MAP.md
│   ├── cpusetup-variables.csv
│   └── UNDERVOLT-REVERSE.md
├── README.md
├── tools/
│   ├── analyze-lnl-fspm-uvp/
│   │   ├── kls71-uvp-policy-map.py
│   │   └── README.md
│   ├── lnl-undervolt/
│   │   ├── lnl-undervolt.c
│   │   ├── Makefile
│   │   └── README.md
│   ├── lnl-uvp-pcode/
│   │   ├── lnl-uvp-pcode.c
│   │   ├── Makefile
│   │   └── README.md
│   └── README.md
├── uefi/
│   ├── BDPROCHOT.c
│   ├── BDPROCHOT.efi
│   ├── BDPROCHOT-RESTORE.c
│   ├── BDPROCHOT-RESTORE.efi
│   ├── README.md
│   ├── Yoga14ILL10-PERFORMANCE-MAX.nsh
│   └── Yoga14ILL10-PERFORMANCE-MAX-ROLLBACK.nsh
└── windows/
    ├── Yoga14ILL10-PERFORMANCE-MAX.ps1
    └── Yoga14ILL10-PERFORMANCE-MAX-ROLLBACK.ps1
```

## PERFORMANCE MAX profile

`uefi/Yoga14ILL10-PERFORMANCE-MAX.nsh` is the consolidated firmware profile. It is designed for **maximum practical CPU + Arc iGPU performance without throwing away Lunar Lake's useful idle and perf/W mechanisms**.

### CPU / HWP

The profile keeps dynamic CPU power management available instead of forcing the processor to run flat-out at idle:

```text
Turbo Mode                       enabled
Intel SpeedStep / EIST           enabled
Intel Speed Shift / HWP          enabled
HWP per-core autonomy            enabled
HWP EPP grouping                 enabled
HWP lock                         disabled
Boot Max Frequency               enabled
Boot Performance Mode            Turbo Performance
Race To Halt                     enabled
C-states / C1E                   enabled
Package C-State Limit            Auto
Energy Efficient P-state         enabled
Energy Efficient Turbo           enabled
DFD debug fabric                 disabled
Power Floor Management           enabled
```

Keeping EIST/HWP, C-states and Race-To-Halt enabled is intentional. On this machine, forcing all C-states off reduced practical Turbo behavior, while the dynamic path allows fast boost under load and low package power between bursts.

### Package power and transient headroom

```text
Package PL1                      37 W
Platform PL1                     37 W
Platform PL2                     37 W
Package power-limit lock         off
Reactive PL4 Boost               63 W
ThETA Ibatt                      off
PROCHOT Demotion                 off
VrAlert Demotion                 off
BCLK Spread                      off
Acoustic Noise Mitigation        off
Core / GT / ATOM slow slew       fastest exposed values
Configurable Base Power path     normal cTDP/Assured-Power path
```

`PL4 Boost = 7.5 W` was the first value directly observed to remove the old persistent battery EDP state. `63 W` is the maximum value exposed by the recovered IFR and is retained as an **aggressive maximum-headroom experiment**, not as proof that 63 W is required.

### CPU and iGPU load-line tuning

The active profile enables the P-core and GT VR configuration blocks and applies:

```text
P-core AC Loadline               2.50 mOhm
GT / iGPU AC Loadline            2.50 mOhm
```

These are **VR/load-line tunes**, not MSR `0x150` voltage-offset undervolts. The observed reference values were approximately `4.00 mOhm` for the P-core domain and `3.00 mOhm` for GT. If instability appears, restore the corresponding AC-loadline field to `0` / Auto.

DC load-line, ICCMAX, TDC, Fast Vmode and the hard VR/current protection fields are intentionally left untouched.

### LPDDR5X / System Agent / iGPU perf-per-watt

The profile also uses the KLS71 `SaSetup` controls recovered from the exact firmware:

```text
Maximum memory-frequency ceiling 8533 MT/s
SAGV                              enabled
SAGV points                       all four enabled
Individual SAGV clocks/gears      Auto
Memory Power Down                 Auto
Page Close Idle Timeout           enabled
Cycle Bypass                      enabled
Memory Scrambler                  enabled
Probeless Trace                   disabled
GT configuration                  enabled
RC6 Render Standby                enabled
MC6 Media Standby                 enabled
Memory Bandwidth Compression      enabled
```

The `8533 MT/s` value is a **maximum ceiling**, not a forced permanent memory clock. SAGV and memory power-down remain enabled so the memory and System Agent can still reduce power when bandwidth is not needed. RC6/MC6 remain enabled for the same reason on the graphics/media side.

### Intel IPF / Dynamic Tuning

The PERFORMANCE MAX BIOS profile does **not** modify `DptfConfig` / Intel IPF firmware variables. Earlier Windows testing showed that the Windows-only low-power state could be corrected through the power plan, so permanently disabling the OEM IPF manager in firmware is not part of the active profile.

## Windows policy: performance on AC, efficiency on battery

After selecting the **Ultimate Performance** power plan, run `windows/Yoga14ILL10-PERFORMANCE-MAX.ps1` from an elevated PowerShell.

The policy deliberately differs between AC and DC:

| Setting | AC / plugged in | DC / battery |
|---|---:|---:|
| Processor minimum | 100% | 5% |
| Processor maximum | 100% | 100% |
| HWP EPP | 0 | 128 |
| Minimum unparked cores | 100% | 10% |
| Boost policy | Aggressive | Efficient Aggressive |

The AC side preserves the configuration that fixed the observed Windows-only ~8 W low-power behavior. The DC side allows normal Lunar Lake HWP scaling and core parking so the performance profile does not unnecessarily turn normal light-use battery life into a constant maximum-power workload.

The BIOS still exposes up to the configured 37 W target under real load; it does **not** force the package to consume 37 W while idle.

## Applying the profile

The scripts are tied to the exact tested KLS71 firmware layout.

1. Put `setup_var.efi`, `uefi/Yoga14ILL10-PERFORMANCE-MAX.nsh` and `uefi/BDPROCHOT.efi` on the UEFI Shell volume.
2. Run `Yoga14ILL10-PERFORMANCE-MAX.nsh`.
3. Fully shut down the machine and cold boot so the persistent setup variables are reinitialized.
4. If BD PROCHOT is desired for that boot, enter the UEFI Shell again and run the script once more before booting Windows. `BDPROCHOT.efi` changes runtime `MSR_POWER_CTL` state and firmware can restore it across a reboot.
5. In Windows, select **Ultimate Performance**, open an elevated PowerShell, and run `windows/Yoga14ILL10-PERFORMANCE-MAX.ps1`.

## Full rollback

`uefi/Yoga14ILL10-PERFORMANCE-MAX-ROLLBACK.nsh` restores the KLS71 **reference/OEM values for every persistent `CpuSetup` and `SaSetup` field written by PERFORMANCE MAX**. In particular it:

- removes the custom 37 W Package/Platform PL1/PL2 programming and returns those paths to firmware-default programming;
- restores Reactive PL4 Boost to `0`;
- restores `PROCHOT Demotion` to Hardware Default and `VrAlert Demotion` to Enabled;
- restores BCLK Spread to Enabled;
- restores P-core and GT AC load-lines to `0` / Auto;
- restores maximum memory frequency to `0` / Auto while keeping the OEM SAGV/RC6/MC6/MBC defaults;
- restores HWP Lock to its reference/default Enabled value;
- calls `BDPROCHOT-RESTORE.efi`, which sets only `MSR_POWER_CTL (0x1FC) bit 0` and preserves every other bit.

After running the UEFI rollback, perform a **full shutdown and cold boot**.

Then run `windows/Yoga14ILL10-PERFORMANCE-MAX-ROLLBACK.ps1` from an elevated PowerShell. It switches Windows back to the built-in **Balanced** plan without deleting the modified Ultimate Performance plan or resetting unrelated custom power plans.

This rollback is a **stock-reference rollback**, not a snapshot restore. If custom values existed before PERFORMANCE MAX, they cannot be reconstructed unless they were recorded beforehand. For the broadest OEM reset, BIOS **Load Setup Defaults** remains authoritative.

## BD PROCHOT helper

`BDPROCHOT.efi` clears only `MSR_POWER_CTL (0x1FC) bit 0`, the package-level bidirectional/external PROCHOT input bit. It preserves the remaining MSR bits. `BDPROCHOT-RESTORE.efi` performs the inverse RMW and sets only bit 0.

Internal CPU Thermal Monitor and TCC are not disabled by this helper. However, external PROCHOT can be part of the OEM platform-protection path, so this remains a deliberate performance-oriented modification rather than a stock-safety setting.

## Reverse-engineering highlights

- `CpuSetup +0x08` is the recovered **Intel SpeedStep / EIST** control on KLS71.
- `CpuSetup +0x0A` is the recovered **Intel Speed Shift / HWP** control.
- `CpuSetup +0x0D/+0x0E` control autonomous per-core HWP and HWP EPP grouping.
- `CpuSetup +0x1EB` is **Energy Efficient Turbo**.
- `CpuSetup +0x237` is the recovered **HWP Lock** field used by the active profile to keep runtime OS HWP policy writable.
- `CpuSetup +0xFA` is the recovered **Overclocking Lock**. Clearing it changes the observed OC-lock state but does not clear UVP.
- Runtime state can be `OC Lock=0`, `OC Secure=0`, `UVP=1`, proving those controls are distinct on this platform.
- MCHBAR is obtained from PCI `00:00.0 + 0x48`; the PCODE mailbox used here is at `MCHBAR + 0x5DA0/+0x5DA4`.
- PCODE OC interface `0x37`, subcommand `0x16` reads UVP and `0x17 DATA=0` requests UVP off. The write is already `PCODE_LOCKED` at runtime and at the tested normal pre-OS timings.
- Two real `LNLUPD_M` structures exist at ROM offsets `0x00D56764` and `0x01156764`.
- The battery transition investigated during the reverse was package-wide: `MSR 0x64F` changed while the visible HWP request and RAPL limit values remained unchanged.
- `CpuSetup +0x2C` (`Reactive Power Limit 4 Boost`) was the first setting that causally changed that persistent EDP behavior.

## Documentation

Start with `docs/BIOS-REVERSE-MAP.md` for the consolidated BIOS map and the recovered CPU power/VR controls.

Use `docs/BATTERY-EDP-REVERSE.md` for the battery/EDP/Reactive-PL4 investigation and the paths already ruled out. Use `docs/UNDERVOLT-REVERSE.md` for the OC-lock, UVP, PCODE, FSP-M and MSR `0x150` research.

## Safety boundary

The active profile keeps **Thermal Monitor, TCC, VR thermal alert, ICCMAX, TDC, Fast Vmode, hard current limits and EC/BMS protections** intact. It also leaves Intel IPF/DTT firmware configuration untouched.

The following parts are intentionally more aggressive than stock and should be treated as tuning experiments:

- Reactive PL4 Boost at the IFR maximum `63 W`;
- P-core and GT AC load-line at `2.50 mOhm`;
- BCLK spread disabled;
- PROCHOT/VrAlert demotion algorithms disabled;
- external BD PROCHOT disabled when `BDPROCHOT.efi` is executed.

Do not reuse these offsets on another machine or BIOS revision without re-extracting the IFR and verifying the varstore layout.

## Contributing

Useful contributions are exact IFR extracts, disassembly references, repeatable live traces and corrections that clearly distinguish **confirmed**, **observed**, **inferred** and **unknown** behavior. Do not submit Lenovo firmware binaries.
