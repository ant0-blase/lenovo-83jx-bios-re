# UEFI Shell profile

These files target only the tested **Lenovo Yoga Slim 7 14ILL10 / 83JX** with the exact `KLS71` firmware layout used by this reverse. Revalidate the IFR and varstores after any BIOS update before reusing the offsets.

## `Yoga14ILL10-PERFORMANCE-MAX.nsh`

This is the single active UEFI tuning profile in the repository. Its goal is **maximum practical CPU + Arc iGPU performance while retaining the dynamic mechanisms that improve idle power, battery life and temperature when the machine is not fully loaded**.

The profile combines:

```text
CPU / HWP
  Turbo / EIST / Speed Shift       enabled
  HWP autonomous per-core policy   enabled
  HWP lock                         disabled
  Race To Halt                     enabled
  C-states / C1E                   enabled
  Package C-state                  Auto
  Energy Efficient P-state/Turbo   enabled

Power / clocks
  Package PL1                      37 W
  Platform PL1 / PL2               37 W / 37 W
  Reactive PL4 Boost               63 W
  BCLK Spread                      disabled
  PROCHOT / VrAlert demotion       disabled

VR tune
  P-core AC load-line              2.50 mOhm experimental
  GT AC load-line                  2.50 mOhm experimental

Memory / iGPU efficiency
  LPDDR5X maximum ceiling          8533 MT/s
  SAGV                              enabled, four points
  Memory power-down                Auto
  RC6 / MC6                        enabled
  Memory Bandwidth Compression     enabled
```

The script intentionally does **not** disable Thermal Monitor, TCC, VR thermal alert, ICCMAX, TDC, Fast Vmode, hard current protection or EC/BMS protections. It also leaves `DptfConfig` / Intel IPF firmware variables untouched.

## `BDPROCHOT.efi`

`BDPROCHOT.efi` performs a read-modify-write of package `MSR_POWER_CTL (0x1FC)` and clears only bit 0 (`ENABLE_BIDIR_PROCHOT`). It preserves every other bit in the MSR.

The source is kept in `BDPROCHOT.c` beside the binary.

This helper does **not** disable the CPU's internal Thermal Monitor or TCC, but external PROCHOT can still be part of the OEM platform protection path. Treat it as an explicit performance-oriented modification.

Because this MSR is runtime state, firmware can restore it during a reboot. Persistent setup variables and the BD PROCHOT helper therefore have different application timing.

## Apply

```text
1. Boot a UEFI Shell with setup_var.efi available.
2. Run Yoga14ILL10-PERFORMANCE-MAX.nsh.
3. Fully shut down and cold boot.
4. If external BD PROCHOT should be disabled for the Windows boot, enter the
   UEFI Shell again and run the script once more before booting Windows.
5. Apply windows/Yoga14ILL10-PERFORMANCE-MAX.ps1 from elevated PowerShell after
   selecting the Ultimate Performance power plan.
```

The Windows companion deliberately uses maximum-performance settings on AC and a battery-efficient HWP/EPP/core-parking policy on DC.
