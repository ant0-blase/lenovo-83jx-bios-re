# Battery / EDP / Reactive PL4 reverse

This document records the full reasoning chain behind the reproducible performance transition around **80 -> 79% battery** on the tested Lenovo Yoga Slim 7 14ILL10 (83JX).

## Symptom

Under sustained CPU load, the machine could sustain roughly the high-30-watt range at higher state of charge, then move to a lower-power state around the displayed 80 -> 79% transition. Reapplying firmware settings could temporarily restore the higher-power behavior, but the transition returned on a later discharge crossing.

The displayed battery percentage is coarse; the actual event can occur while the UI still reports 80%.

## Decisive package signal

`MSR 0x64F` changed package-wide on all logical CPUs:

```text
before: 0x19030800
later : 0x19030100
sometimes: 0x19030102
```

For the bits used in this investigation:

- bit 11 active in `...0800`: PL2/package-platform power-limit activity;
- bit 8 active in `...0100`: OTHER / EDP electrical-design-point limitation;
- bit 1 was only transient in the `...0102` samples.

The change occurred on every CPU together, which is consistent with a package/platform electrical policy rather than a single-core scheduler decision.

## Exact transition trace

A captured transition showed:

```text
19:30:10.716  BAT=80  V=7.998 V  P=52.202 W  64F=19030800
19:30:11.721  BAT=80  V~7.998 V P~52.2 W 64F=19030800
19:30:12.750  BAT=80  per-CPU 64F already moved to 19030100
19:30:13.781  BAT=79  V=7.998 V  P=52.186 W  64F=19030102
```

After the clamp engaged, system battery power fell and voltage recovered. The voltage did **not** collapse before the event, which weakens a simple fixed-voltage-threshold explanation. A combined RSOC/peak-current policy remains possible.

At substantially lower SOC (around 42% in an earlier sustained trace), the EDP state persisted under load, showing that the below-threshold policy remains active once entered.

## HWP / Linux ruled out as the direct trigger

At the transition, the HWP requests did not change:

```text
CPU0  0x3705
CPU1  0x3806
CPU2  0x3705
CPU3  0x3806
CPU4-7 0x2504
HWP_STATUS (0x777) = 0
```

The Linux platform profile remained `performance`. The switch to `0x19030100` happened without a matching HWP request change. This rules out `intel_pstate`/HWP as the direct cause of the package-wide EDP assertion.

## RAPL / visible limit state did not change

Observed live values included:

```text
MSR 0x606 = 0xA0E03
MSR 0x610 = 0x8000812800DD8128
MSR 0x65C = 0x812800DD8128
MSR 0x601 = 0x2F8
```

The power-unit low nibble in `0x606` is `3`, giving 1/8 W units for the relevant RAPL power fields. The `0x128` fields correspond to 296 / 8 = **37 W**. `0x610` and `0x65C` did not change across the event.

`MSR 0x601=0x2F8` also stayed unchanged. In this investigation it must not be confused with the firmware's `CpuSetup + 0x27` PL4-power field; the live `0x601` value is a current-limit style encoding and its lack of change does not prove that an external Reactive-PL4/FORCEPR path is inactive.

## Thermal/current status

Before the drop, `IA32_THERM_STATUS (0x19C)` commonly looked like:

```text
0x88103C08
0x88123C08
```

with Current Limit Status / log activity. After the CPU was clipped, samples such as `0x88112808` could have the instantaneous current-status bit clear while the historical log remained set. That is expected if the limiter has already reduced the load; it does not contradict `0x64F bit8` being the active package limiter.

## Warm reboot result

A normal warm reboot did not remove the electrical state:

```text
before reboot under load: 0x19030100
after reboot under load : 0x11020100
```

The EDP/OTHER bit remained active. This is evidence against a purely Linux-local state and is compatible with an EC/platform controller/Pcode policy that remains powered across a warm reset.

## Static paths audited and eliminated

The following static `CpuSetup` paths were checked or tested:

- ISYS L1: `0x1D9 = 0x0094` = 18.5 A, enable `0x1DB = 0`;
- ISYS L1 tau: `0x1DC = 0x1C`;
- ISYS L2: `0x1DD = 0x0080` = 16 A, enable `0x1DF = 0`;
- ThETA Ibatt `0x1E0 = 0`;
- VrAlert Demotion `0x3D9 = 0` in the tuned profile;
- TDC currents `0x191/0x193/0x195/0x197 = 0`, TDC enables `0x19D..0x1A0 = 1`, windows `0x1A3/0x1A7/0x1AB/0x1AF = 0`, P/GT mode `0x44A/0x44B = 0`.

A current value of zero must not be interpreted as “TDC disabled” when the enable field is one; it means the firmware/hardware default path is being used.

A moderate ICCMAX causal test changed P-core 54 A -> 64 A and E-core 28.5 A -> 32 A. The SOC transition still occurred. Raising ICCMAX further was therefore rejected as a useful fix.

## Failed causal fixes

These experiments did not solve the transition:

- `PSYS PMax = 60 W` (`CpuSetup + 0x10B = 480`);
- Assured Power/cTDP bypass (`0x236 = 0`) — instead caused about a **16 W** low-power fallback;
- Base Power Boot Mode raw value `0x45 = 2` — no useful fix, and the exact semantic mapping of value 2 is not considered safely verified;
- DYTC/platform-profile refresh;
- `ideapad_acpi` unbind/rebind;
- moderate ICCMAX increase;
- static ISYS/ThETA/VrAlert changes alone.

The clean baseline remains:

```text
PSYS PMax              0x10B = 0 (AUTO)
Base Power Boot Mode   0x45  = 0 (Nominal)
Configurable Base Power 0x236 = 1 (normal cTDP/Assured Power init)
```

## Why Reactive PL4 fits

The firmware IFR exposes:

```text
0x26  Power Limit 4 Override   default 1
0x27  Power Limit 4            default 95000 mW
0x2B  Power Limit 4 Lock       default 0
0x2C  Power Limit 4 Boost      0..63000 mW, 125 mW step, default 0
```

Intel's Reactive-PL4 architecture is specifically designed around short electrical/peak-power constraints and, on battery platforms, can be state-of-charge dependent. That is a much closer architectural match to the observed RSOC-correlated EDP transition than another static PL1/PL2 field.

This is still an architectural match, not proof that Lenovo implements every public Intel reference flow exactly.

## Causal PL4-Boost result

The first decisive improvement came from:

```text
CpuSetup + 0x2C = 7500 mW
```

At 78% battery, under the same load, `MSR 0x64F` sampled:

```text
19030800
19030800
19030900
19030800
```

The previous persistent `...0100` EDP state was gone; bit8 only appeared transiently in `...0900` while PL2 remained active. That makes `PL4 Boost` a **causal control for the problematic behavior** on this machine.

A later 15 W boost improved headroom but was still described as insufficient for maximum observed CPU+iGPU performance. The current `Yoga14ILL10-Battery37W-BCLK.nsh` therefore contains the user-requested IFR maximum:

```text
CpuSetup + 0x2C = 63000 mW
```

That 63 W value is an **aggressive experiment**, not a separately proven optimum. It increases the allowed reactive headroom and can increase transient battery droop/current and VR stress even though thermal/VR/EC/BMS protections remain enabled.

## Remaining unknown

The exact Lenovo/Intel code branch that converts battery state into the live reactive electrical request has **not** been located. ACPI/EC scans found useful platform structures but no safe literal “80% clamp” branch. The remaining path is likely in EC/PMC/Pcode/dynamic VR/battery-budget logic rather than a simple Linux power policy.
