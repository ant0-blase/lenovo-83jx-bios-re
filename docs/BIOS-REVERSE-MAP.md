# Complete BIOS reverse map

This is the consolidated **A-to-Z map** of everything currently known about the tested Lenovo Yoga Slim 7 14ILL10 / 83JX firmware. It intentionally distinguishes direct firmware facts, live observations, causal tests and hypotheses.

## Confidence labels

- **CONFIRMED** — directly recovered from IFR/disassembly or reproduced with an unambiguous low-level effect.
- **OBSERVED** — captured live on the target machine.
- **CAUSAL** — changing one control changed the target behavior in the expected direction.
- **INFERRED** — strong architectural/code-path inference, but not yet proven end-to-end.
- **UNKNOWN** — unresolved; do not convert into a write merely because an offset exists.

## Firmware identity and varstore

```text
Machine:     Lenovo Yoga Slim 7 14ILL10 / 83JX
Platform:    Intel Lunar Lake / Core Ultra 200V
Tested CPU:  Core Ultra 7 258V
ROM:         KLS71_sign.rom
ROM SHA256:  21ff6995dc89ee637aceba0f0c37aa9b3b04292d04b8fe7240e512a7874c86bd

CpuSetup VarStoreId: 0x3
CpuSetup GUID:       75E3088B-88BB-490F-AA29-FAA83244E8E3
CpuSetup size:       0x458 bytes
```

`setup_var.efi` size operands used in this repository are byte counts: `(1)` for an 8-bit field, `(2)` for 16-bit, `(4)` for 32-bit.

## UEFI / pre-memory modules recovered

### `PlatformInitPreMem`

A duplicated `PlatformInitPreMem` PE32+ x86-64 EFI boot-service image was extracted from the `CF1406C5-3FEC-47EB-A6C3-B71A3EE00B95` firmware volume. One analyzed copy:

```text
SHA256: 1a3e8ab2c809f7883634b35fc7ec0c2e7e2caf6c931f4b6ca8953cf2e3e3d494
ImageBase: 0xFFD8EB60
Entry RVA: 0x42C
.text: RVA/raw 0x2A0, VSZ 0x7EEE, raw size 0x7F00
.data: RVA/raw 0x81A0, VSZ 0x3D58, raw size 0x3D60
SizeOfImage: 0xCB20
```

This module and related platform data were disassembled during the battery-policy hunt. No exact literal “80% SOC clamp” branch has been proven inside it; do not claim one.

### `FspInitPreMem` and `SiInitPreMemFsp`

The exact TE images were disassembled and used to recover the FSP-M policy copy chain and early PCODE calls. This is currently the strongest path for continuing the UVP reverse.

## FSP-M / `LNLUPD_M`

Two real duplicated FSP-M UPD structures are located at ROM file offsets:

```text
0x00D56764
0x01156764
```

Key values in both:

```text
+0x884 = 0x02
+0x885 = 0x01
+0x886 = 0x00
+0x887 = 0x00
+0x888 = 0x00
+0x896 = 0x00   UnderVoltProtection input
+0x897 = 0x00   adjacent Vsys-critical path
+0x898 = 24000  Vsys-scale sequence
+0x89C = 6000   Vsys-critical threshold sequence
+0x8A0 = 200000 Psys-scale sequence
+0x8A4 = 130000 Psys-critical threshold sequence
```

`FspInitPreMem` mapping:

```text
FSPM +0x884 -> internal policy +0xF7
FSPM +0x885 -> internal policy +0xF8
FSPM +0x886 -> internal policy +0xF9   CONFIRMED
FSPM +0x887 -> internal policy +0xFA   CONFIRMED
FSPM +0x888 -> internal policy +0xFB   CONFIRMED
FSPM +0x896 -> internal policy +0x13B  CONFIRMED
FSPM +0x897 -> internal policy +0x160
```

`SiInitPreMemFsp` checks policy `+0x13B` and, when non-zero, sends raw PCODE command `0x48` with `DATA=1`. It also packs `+0xF9/+0xFA/+0xFB` into a PCODE `0x0A` payload.

## Overclocking / UVP / PCODE

### Normal OC lock

```text
CpuSetup +0xFA = Overclocking Lock
```

Setting it to zero cleared the observed `MSR 0x194 bit20`. It did **not** clear `MSR 0x195 bit1` (UVP).

### Live state after OC-lock clear

```text
MSR 0x194 = 0x0000000000010000
MSR 0x195 = 0x0000000000000002
OC Lock bit20 = 0
UVP bit1      = 1
OC Secure bit2= 0
```

### PCODE mailbox

```text
MCHBAR PCI source: 00:00.0 + 0x48
PCODE DATA:         MCHBAR + 0x5DA0
PCODE INTERFACE:    MCHBAR + 0x5DA4
OC command:         0x37
read UVP:           subcommand 0x16
write UVP:          subcommand 0x17, DATA=0
PCODE_LOCKED:       completion 0x06
```

Linux, normal UEFI and BDS Driver#### tests all reached a locked write path. The inferred raw FSP-style `0x48 DATA=0` attempt was also locked at normal UEFI time.

### Early hidden bytes

A separate wrapper reverse produced the read-only candidate chain:

```text
CpuSetup +0x2F3 -> early policy byte / PCODE 0x0A payload byte 0
CpuSetup +0x2F4 -> early policy byte / PCODE 0x0A payload byte 1
CpuSetup +0x2F5 -> early policy byte / PCODE 0x0A payload byte 2
```

Their names/semantics are not IFR-proven. No active script writes them.

## MSR 0x150 voltage path

The recovered undervolt utility uses:

```text
OC mailbox MSR: 0x150
command 0x10: read voltage offset
command 0x11: write voltage offset
plane 0: Core / IA   (writes enabled by this project)
plane 2: Ring / Cache (writes enabled by this project)
```

Other legacy plane IDs remain unproven for Lunar Lake writes. See `UNDERVOLT-REVERSE.md`.

## Package / platform power-limit map

```text
0x13  Package PL1 power
0x17  Package PL1 override
0x1E  PL3 override
0x1F  PL3 power
0x23  PL3 time window
0x24  PL3 duty cycle
0x25  PL3 lock
0x26  PL4 override
0x27  PL4 power (IFR default 95000 mW)
0x2B  PL4 lock
0x2C  PL4 Boost (0..63000 mW)
0x30  PACKAGE_POWER_LIMIT MSR lock request
0x31  Platform PL1 enable
0x32  Platform PL1 power
0x36  Platform PL1 time window
0x37  Platform PL2 enable
0x38  Platform PL2 power
```

Current tuned power path uses package PL1 37 W plus platform PL1/PL2 37 W. The current max-performance script uses PL4 Boost 63 W; 7.5 W is the first causally validated value for eliminating the persistent SOC EDP clamp.

## Live package MSRs

```text
0x606 = 0xA0E03
0x610 = 0x8000812800DD8128
0x65C = 0x812800DD8128
0x601 = 0x2F8
```

`0x606` gives 1/8 W power units for the relevant RAPL fields. The `0x128` fields decode to 37 W. The visible `0x610/0x65C/0x601` values stayed unchanged across the 80% transition.

`0x601=0x2F8` is treated as a current-limit style field in this reverse; it is not the same thing as `CpuSetup +0x27` PL4 power.

## Performance-limit MSR behavior

```text
normal/high-SOC load: 0x64F = 0x19030800
problem state:        0x64F = 0x19030100
transient sample:     0x64F = 0x19030102
```

The transition is package-wide. HWP requests stayed fixed while bit8 OTHER/EDP asserted. With Reactive PL4 Boost enabled, the bad persistent state changed to normal `0x19030800` with only transient `0x19030900` samples.

## BCLK / RFI

```text
0x222  BCLK RFI frequency - SAGV Low   (4 bytes, default 0)
0x226  BCLK RFI frequency - SAGV Mid   (4 bytes, default 0)
0x22A  BCLK RFI frequency - SAGV High  (4 bytes, default 0)
0x22E  BCLK RFI frequency - SAGV Max   (4 bytes, default 0)
0x232  BCLK Spread                      (0 disabled, 1 enabled/default)
```

The active profile changes only `0x232`; the four RFI/SAGV frequency fields are left at their original values.

Separate DLVR RFI controls exist at `0x2FD..0x301`; they are **not** the same as BCLK Spread and are not part of the active performance profile.

## VR / load-line / current map

### Domain configuration and load-line

```text
P-core: enable 0x10D, AC 0x113, DC 0x11F, ICCMAX 0x185
GT:     enable 0x10E, AC 0x115, DC 0x121, ICCMAX 0x187
SA:     enable 0x10F, AC 0x117, DC 0x123, ICCMAX 0x189
E-core: enable 0x110, AC 0x119, DC 0x125, ICCMAX 0x18B
L2:     enable 0x111, AC 0x11B, DC 0x127
VDDQ:   enable 0x112
```

Observed snapshot:

```text
P-core   Enable=1 AC_LL=0 DC_LL=0 ICC=216 -> 54 A
GT/iGPU  Enable=1 AC_LL=0 DC_LL=0 ICC=244 -> 61 A
SA       Enable=1 AC_LL=0 DC_LL=0 ICC=208 -> 52 A
E-core   Enable=1 AC_LL=0 DC_LL=0 ICC=114 -> 28.5 A
```

ICCMAX uses 1/4 A increments in the recovered IFR.

### TDC

```text
Current: 0x191 P, 0x193 GT, 0x195 SA, 0x197 E
Enable:  0x19D P, 0x19E GT, 0x19F SA, 0x1A0 E
Window:  0x1A3 P, 0x1A7 GT, 0x1AB SA, 0x1AF E
Lock:    0x1BB P, 0x1BC GT, 0x1BD SA, 0x1BE E
Mode:    0x44A P, 0x44B GT, 0x44C SA, 0x44D E
```

Live audit found current override 0, enable 1, window 0 and iPL2 mode 0. Zero current does not mean TDC is off when enable is one.

### Fast Vmode

ICC thresholds are at `0x33B/0x33D/0x33F/0x341/0x343/0x345`; Core/GT/SA enable fields are `0x348/0x349/0x34A` and default enabled. These are protective/high-risk controls and were not disabled.

## PSYS / VSYS / battery-current policy

```text
0x105 PSYS Slope          default 0 AUTO
0x106 PSYS Offset         default 0
0x10A PSYS Prefix         default +
0x10B PSYS PMax           1/8 W units, default 0 AUTO
0x1D9 ISYS L1 current
0x1DB ISYS L1 enable
0x1DC ISYS L1 tau
0x1DD ISYS L2 current
0x1DF ISYS L2 enable
0x1E0 ThETA Ibatt
0x1E1 Vsys Max            default 0 AUTO
0x304 Vsys/Psys Critical  0 disabled, 1 Psys, 2 Vsys
0x351 Vsys full scale     24000
0x355 Vsys critical       6000
0x359 Psys full scale     200000
0x35D Psys critical       130000
```

ACPI contains an Intel `UPIS` flow. When the ThETA/ISYS enable path is active it can update ISYS bits in `ISCL`; the disabled path contains the diagnostic string `ThETA Ibatt disable!`.

## Thermal / PROCHOT / skin controls

Important recovered controls include:

```text
0x43  Thermal Monitor                         default enabled
0x6B  Disable VR Thermal Alert                default 0 (alerts not disabled)
0x6D  PROCHOT Response                        default enabled
0x1CB TCC Offset Clamp Enable
0x1CC TCC Offset Lock Enable
0x3D8 PROCHOT Demotion                        hardware default
0x3D9 VrAlert Demotion                        default enabled
0x3E7 Skin Control Temperature Enable MMIO    default disabled
0x3EA Skin Temperature Loop Gain              0..7, default 0
0x3ED Skin Temperature Override Enable        default disabled
0x3F0 Skin Temperature Minimum Performance    0..255, default 0
0x3F3 Skin Temperature Override               0..255, 0.5 C units
```

The IFR help for `0x3F0` mentions “256 - no throttling allowed” while the recovered numeric range ends at 255. That contradiction is preserved rather than silently corrected. Skin controls are not considered the leading cause of the SOC-correlated EDP transition.

## DLVR / RFI controls

```text
0x2FD DLVR SSC Value: 0=0%, 2=0.5%, 4=1%, 8=2%, 16=4% (default 2)
0x2FE DLVR RFI Frequency: 0=2227 MHz, 1=2140 MHz
0x300 Global DLVR RFI Mitigation: default enabled
0x301 DLVR PHASE_SSC: default disabled
```

These are documented/recovered but intentionally not part of the current performance script.

## Platform rail / board data

A raw board/rail table under GUID `338FA35A-CA4A-4DBC-A6F4-9BD1593B61BC` contains names including:

```text
CPU_VCCSA, CPU_VDD2H, CPU_VCCL2, CPU_VCCIA, CPU_VCCGT, CPU_VDD2L,
CPU_V1P8U_MEM, CPU_VDDQ, CONNECTIVITY_WLAN, CAMERA_V3P3, CAMERA_V1P8,
CPU_VCCST, CPU_VCC1P5_RTC, SYSTEM_VBATA, STORAGE_SSD, PMIC_INPUT,
TYPE-C_PORT2, TYPE-C_PORT1, TYPE-C_PORT0, DISPLAY_BKLT, CPU_VCC3P3,
CPU_VCCDDRIO, DISPLAY_3P3_EDP, CPU_VCC1P8, CPU_VNNAON
```

One recovered group (`id=0x15`) contains `CPU_VCC1P5_RTC` type `0x0A`, `SYSTEM_VBATA` type `0x02`, `STORAGE_SSD` type `0x05` and `PMIC_INPUT` type `0x01`. This is useful topology metadata, **not proof that the table implements the 80% policy**.

`AcpiPlatformFeatures` also contains battery full-resolution voltage descriptors. Again, those strings prove platform telemetry capability, not the clamp algorithm itself.

## Complete recovered CpuSetup IFR index

The table below is generated from `docs/cpusetup-variables.csv`. The CSV remains the machine-readable source, including ranges, defaults, confidence and literal IFR help. The BCLK entries were added from the later IFR/BCLK reverse so this index now contains **187** recovered entries.

| Offset | Bytes | Domain | Name | Type / encoding | Default | Risk | State | IFR help / recovered meaning |
|---:|---:|---|---|---|---|---|---|---|
| `0x10` | 1 |  | C states | 0 Disabled · 1 Enabled | 1 | 🟠 | ✅ IFR | Enable/Disable CPU Power Management. Allows CPU to go to C states when it's not 100% utilized. |
| `0x11` | 1 |  | Enhanced C-states | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🟠 | ✅ IFR | Enable/Disable C1E. When enabled, CPU will switch to minimum speed when all cores enter C-State. |
| `0x12` | 1 |  | Turbo Mode | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🟠 | ✅ IFR | Enable/Disable processor Turbo Mode. |
| `0x13` | 4 |  | Power Limit 1 | 0..4095875 mW, pas 125 mW | 0 | 🔴 | ✅ IFR | Power Limit 1 in Milli Watts. BIOS will round to the nearest 1/8W when programming. 0 = no custom override. For 12.50W, enter 12500. Overclocking SKU: Value must be between Max and Min Power Limits. Other SKUs: This value must be between Min Power Limit and Processor Base Power (TDP) Limit. If value is 0, BIOS will program Processor Base Power (TDP) value. |
| `0x17` | 1 |  | Power Limit 1 Override | 0 Disabled · 1 Enabled | 0 | 🔴 | ✅ IFR | Enable/Disable Power Limit 1 override. If this option is disabled, BIOS will program the default values for Power Limit 1 and Power Limit 1 Time Window. |
| `0x1E` | 1 |  | Power Limit 3 Override | 0 Disabled · 1 Enabled | 0 | 🔴 | ✅ IFR | Enable/DisablePower Limit 3 override. If this option is disabled, BIOS will leave the hardware default values for Power Limit 3 and Power Limit 3 Time Window. |
| `0x1F` | 4 |  | Power Limit 3 | 0..4095875 mW, pas 125 mW | 0 | 🔴 | ✅ IFR | Power Limit 3 in Milli Watts. BIOS will round to the nearest 1/8W when programming. For 12.50W, enter 12500. XE SKU: Any value can be programmed. Overclocking SKU: Value must be between Max and Min Power Limits. Other SKUs: This value must be between Min Power Limit and Processor Base Power (TDP) Limit. If the value is 0, BIOS leaves the hardware default value |
| `0x23` | 1 |  | Power Limit 3 Time Window | 0 Auto/default; valeurs IFR discrètes jusqu'à 64 s | 0 | 🔴 | ✅ IFR | Power Limit 3 Time Window value in Milli seconds. The value may vary from 3 to 64(max).Indicates the time window over which Power Limit 3 value should be maintained. If the value is 0, BIOS leaves the hardware default value |
| `0x24` | 1 |  | Power Limit 3 Duty Cycle | 0..100 % | 0 | 🔴 | ✅ IFR | Specify the duty cycle in percentage that the CPU is required to maintain over the configured time window. Range is 0-100. |
| `0x25` | 1 |  | Power Limit 3 Lock | 0 Disabled · 1 Enabled | 0 | 🔴 | ✅ IFR | Power Limit 3 Lock. When enabled PL3 configurations are locked during OS. When disabled PL3 configuration can be changed during OS. |
| `0x26` | 1 |  | Power Limit 4 Override | 0 Disabled · 1 Enabled | 1 | 🔴 | ✅ IFR | Enable/Disable Power Limit 4 override. If this option is disabled, BIOS will leave the default values for Power Limit 4. |
| `0x27` | 4 |  | Power Limit 4 | 0..4095875 mW, pas 125 mW | 95000 | 🔴 | ✅ IFR | Power Limit 4 in Milli Watts. BIOS will round to the nearest 1/8W when programming. For 12.50W, enter 12500. If the value is 0, BIOS leaves default value |
| `0x2B` | 1 |  | Power Limit 4 Lock | 0 Disabled (def) · 1 Enabled | 0 (Disabled) | 🔴 | ✅ IFR | Power Limit 4 Lock. When enabled PL4 configurations are locked during OS. When disabled PL4 configuration can be changed during OS. |
| `0x2C` | 4 |  | Power Limit 4 Boost | 0..63000 mW, pas 125 mW | 0 | 🔴 | ✅ IFR | Configure Power Limit 4 Boost in Milli Watts. BIOS will round to the nearest 1/8W when programming. For 12.50W, enter 12500. The value 0 means disable. |
| `0x30` | 1 |  | Package Power Limit MSR Lock | 0 Disabled (def) · 1 Enabled | 0 (Disabled) | 🔴 | ✅ IFR | Enable/Disable locking of Package Power Limit settings. When enabled, PACKAGE_POWER_LIMIT MSR will be locked and a reset will be required to unlock the register. |
| `0x31` | 1 |  | Platform PL1 Enable | 0 Disabled (def) · 1 Enabled | 0 (Disabled) | 🟡 | ✅ IFR | Enable/Disable Platform Power Limit 1 programming. If this option is enabled, it activates the PL1 value to be used by the processor to limit the average power of given time window. |
| `0x32` | 4 |  | Platform PL1 Power | 0..4095875 mW, pas 125 mW | 0 | 🟡 | ✅ IFR | Platform Power Limit 1 Power in Milli Watts. BIOS will round to the nearest 1/8W when programming. Any value can be programmed between Max and Min Power Limits. For 12.50W, enter 12500. This setting will act as the new PL1 value for the Package RAPL algorithm. |
| `0x36` | 1 |  | Platform PL1 Time Window | 0 default; IFR: 1,2,3,4,5,6,7,8,10,12,14,16,20,24,28,32,40,48,56,64,80,96,112,128 s | 0 (0) | 🟡 | ✅ IFR | Platform Power Limit 1 Time Window value in seconds. The value may vary from 0 to 128. 0 = default values. Indicates the time window over which Platform Processor Base Power (TDP) value should be maintained. |
| `0x37` | 1 |  | Platform PL2 Enable | 0 Disabled (def) · 1 Enabled | 0 (Disabled) | 🟡 | ✅ IFR | Enable/Disable Platform Power Limit 2 programming. If this option is disabled, BIOS will program the default values for Platform Power Limit 2. |
| `0x38` | 4 |  | Platform PL2 Power | 0..4095875 mW, pas 125 mW | 0 | 🟡 | ✅ IFR | Platform Power Limit 2 Power in Milli Watts. BIOS will round to the nearest 1/8W when programming. Any value can be programmed between Max and Min Power Limits. For 12.50W, enter 12500. This setting will act as the new Max Turbo Power (PL2) value for the Package RAPL algorithm. |
| `0x3C` | 1 |  | Energy Efficient P-state | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🟡 | ✅ IFR | Enable/Disable Energy Efficient P-state feature. When set to 0, will disable access to ENERGY_PERFORMANCE_BIAS MSR and CPUID Function will read 0 indicating no support for Energy Efficient policy setting. When set to 1 will enable access to ENERGY_PERFORMANCE_BIAS MSR and CPUID Function will read 1 indicating Energy Efficient policy setting is supported. |
| `0x3D` | 1 |  | CState Pre-Wake | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🟠 | ✅ IFR | Disable - to 1 to disable the Cstate Pre-Wake |
| `0x3F` | 1 |  | C-State Auto Demotion | 0 Disabled · 1 C1 (def) | 1 (C1) | 🟠 | ✅ IFR | Configure C-State Auto Demotion |
| `0x40` | 1 |  | C-State Un-demotion | 0 Disabled · 1 C1 (def) | 1 (C1) | 🟠 | ✅ IFR | Configure C-State Un-demotion |
| `0x41` | 1 |  | Package C-State Demotion | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🟠 | ✅ IFR | Package C-State Demotion |
| `0x42` | 1 |  | Package C-State Un-demotion | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🟠 | ✅ IFR | Package C-State Un-demotion |
| `0x43` | 1 |  | Thermal Monitor | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🔴 | ✅ IFR | Enable/Disable Thermal Monitor |
| `0x45` | 1 |  | Configurable Base Power Boot Mode | 0 Nominal (Base Power) (def) · 1 Min Assured Power | 0 (Nominal (Base Power)) | 🟠 | ✅ IFR | Assured Power (cTDP) Mode as Nominal/Level1/Level2/Deactivate Base Power (TDP) selection. Deactivate option will set MSR to Nominal and MMIO to Zero. |
| `0x48` | 1 |  | Timed MWAIT | 0 Disabled (def) · 1 Enabled | 0 (Disabled) | 🟡 | ✅ IFR | Enable/Disable Timed MWAIT Support |
| `0x49` | 1 |  | IO MWAIT Redirection | 0 Disabled (def) · 1 Enabled | 0 (Disabled) | 🟡 | ✅ IFR | When set, will map IO_read instructions sent to IO registers PMG_IO_BASE_ADDRBASE+offset to MWAIT(offset) |
| `0x4A` | 1 |  | Interrupt Redirection Mode Selection | 0 Fixed Priority (def) · 1 Round robin · 2 Hash Vector · 7 No Change | 0 (Fixed Priority) | 🟡 | ✅ IFR | Interrupt Redirection Mode Select for Logical Interrupts |
| `0x4B` | 1 |  | Package C State Limit | 0 C0/C1 · 1 C2 · 2 C3 · 3 C6 · 8 C10 · 254 Cpu Default · 255 Auto | 255 | 🟠 | ✅ IFR | Maximum Package C State Limit Setting. Cpu Default: Leaves to Factory default value.Auto: Initializes to deepest available Package C State Limit. |
| `0x6B` | 1 |  | Disable VR Thermal Alert | 0 Disabled (def) · 1 Enabled | 0 (Disabled) | 🔴 | ✅ IFR | Enable/Disable VR Thermal Alert |
| `0x6D` | 1 |  | PROCHOT Response | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🔴 | ✅ IFR | Enable/Disable PROCHOT Response |
| `0xFA` | 1 |  | Overclocking Lock | 0 clear/disabled · 1 locked/enabled | — | 🟠 | 🧪 testé | Observed/tested CpuSetup lock controlling the OC lock state. Clearing it changed the observed MSR 0x194 OC-lock state, but did not clear Undervolt Protection. |
| `0xFB` | 1 |  | CPU Run Control | 0 Disabled · 1 Enabled · 2 No Change | — | 🟡 | ✅ IFR | Enable/Disable CPU Run Control Support; No Change : Comply with HW value |
| `0xFC` | 1 |  | CPU Run Control Lock | 0..1 | — | 🟠 | ✅ IFR | Enable/Disable CPU Run Control Lock |
| `0xFF` | 1 |  | Processor Trace OutPut Scheme | 0 Single Range · 1 ToPA | — | 🟡 | ✅ IFR | Select Single Range Output scheme or ToPA table Output scheme |
| `0x101` | 1 |  | Processor trace | 0..1 | — | 🟡 | ✅ IFR | Enable/Disable processor trace feature from CPU MSR. Enabling this feature will immediately start trace collection. |
| `0x103` | 1 |  | Three Strike Counter | 0..1 | — | 🟡 | ✅ IFR | Enable/Disable Three Strike Counter |
| `0x105` | 1 |  | PSYS Slope | 0..200 raw /100; 0=AUTO | 0 | 🔴 | ✅ IFR | PSYS Slope defined in 1/100 increments. Range is 0-200. For a 1.25 slope, enter 125. 0 = AUTO. |
| `0x106` | 4 |  | PSYS Offset | 0..128000 raw /1000 | 0 | 🔴 | ✅ IFR | PSYS Offset defined in 1/1000 increments. Range is 0-128000. For an offset of 25.348, enter 25348. |
| `0x10A` | 1 |  | PSYS Prefix | 0 + (def) · 1 - | 0 (+) | 🔴 | ✅ IFR | Sets the offset value as positive or negative. |
| `0x10B` | 2 |  | PSYS PMax Power | 0..8191 raw, pas 0,125 W (1023.88 W max IFR) | 0 | 🔴 | ✅ IFR | PSYS PMax power, defined in 1/8 Watt increments. Range 0-8191. For a PMax of 125W, enter 1000. 0 = AUTO. |
| `0x10D` | 1 | P-core | VR Config Enable | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🟠 | 👀 IFR + lecture live | VR Config Enable |
| `0x10E` | 1 | GT/iGPU | VR Config Enable | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🟠 | 👀 IFR + lecture live | VR Config Enable |
| `0x10F` | 1 | SA | VR Config Enable | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🟠 | 👀 IFR + lecture live | VR Config Enable |
| `0x110` | 1 | E-core | VR Config Enable | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🟠 | 👀 IFR + lecture live | VR Config Enable |
| `0x111` | 1 | L2 | VR Config Enable | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🟠 | ✅ IFR | VR Config Enable |
| `0x112` | 1 | VDDQ | VR Config Enable | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🟠 | ✅ IFR | VR Config Enable |
| `0x113` | 2 | P-core | AC Loadline | 0..6249 raw = 0.00..62.49 mΩ; 0=AUTO | 0 | 🔴 | 👀 IFR + lecture live | AC Loadline defined in 1/100 mOhms. A value of 100 = 1.00 mOhm, and 1255 = 12.55 mOhm. Range is 0-6249 (0-62.49 mOhms). 0 = AUTO/HW default. |
| `0x115` | 2 | GT/iGPU | AC Loadline | 0..6249 raw = 0.00..62.49 mΩ; 0=AUTO | 0 | 🔴 | 👀 IFR + lecture live | AC Loadline defined in 1/100 mOhms. A value of 100 = 1.00 mOhm, and 1255 = 12.55 mOhm. Range is 0-6249 (0-62.49 mOhms). 0 = AUTO/HW default. |
| `0x117` | 2 | SA | AC Loadline | 0..6249 raw = 0.00..62.49 mΩ; 0=AUTO | 0 | 🔴 | 👀 IFR + lecture live | AC Loadline defined in 1/100 mOhms. A value of 100 = 1.00 mOhm, and 1255 = 12.55 mOhm. Range is 0-6249 (0-62.49 mOhms). 0 = AUTO/HW default. |
| `0x119` | 2 | E-core | AC Loadline | 0..6249 raw = 0.00..62.49 mΩ; 0=AUTO | 0 | 🔴 | 👀 IFR + lecture live | AC Loadline defined in 1/100 mOhms. A value of 100 = 1.00 mOhm, and 1255 = 12.55 mOhm. Range is 0-6249 (0-62.49 mOhms). 0 = AUTO/HW default. |
| `0x11B` | 2 | L2 | AC Loadline | 0..6249 raw = 0.00..62.49 mΩ; 0=AUTO | 0 | 🔴 | ✅ IFR | AC Loadline defined in 1/100 mOhms. A value of 100 = 1.00 mOhm, and 1255 = 12.55 mOhm. Range is 0-6249 (0-62.49 mOhms). 0 = AUTO/HW default. |
| `0x11F` | 2 | P-core | DC Loadline | 0..6249 raw = 0.00..62.49 mΩ; 0=AUTO | 0 | 🔴 | 👀 IFR + lecture live | DC Loadline defined in 1/100 mOhms. A value of 100 = 1.00 mOhm, and 1255 = 12.55 mOhm. Range is 0-6249 (0-62.49 mOhms). 0 = AUTO/HW default. |
| `0x121` | 2 | GT/iGPU | DC Loadline | 0..6249 raw = 0.00..62.49 mΩ; 0=AUTO | 0 | 🔴 | 👀 IFR + lecture live | DC Loadline defined in 1/100 mOhms. A value of 100 = 1.00 mOhm, and 1255 = 12.55 mOhm. Range is 0-6249 (0-62.49 mOhms). 0 = AUTO/HW default. |
| `0x123` | 2 | SA | DC Loadline | 0..6249 raw = 0.00..62.49 mΩ; 0=AUTO | 0 | 🔴 | 👀 IFR + lecture live | DC Loadline defined in 1/100 mOhms. A value of 100 = 1.00 mOhm, and 1255 = 12.55 mOhm. Range is 0-6249 (0-62.49 mOhms). 0 = AUTO/HW default. |
| `0x125` | 2 | E-core | DC Loadline | 0..6249 raw = 0.00..62.49 mΩ; 0=AUTO | 0 | 🔴 | 👀 IFR + lecture live | DC Loadline defined in 1/100 mOhms. A value of 100 = 1.00 mOhm, and 1255 = 12.55 mOhm. Range is 0-6249 (0-62.49 mOhms). 0 = AUTO/HW default. |
| `0x127` | 2 | L2 | DC Loadline | 0..6249 raw = 0.00..62.49 mΩ; 0=AUTO | 0 | 🔴 | ✅ IFR | DC Loadline defined in 1/100 mOhms. A value of 100 = 1.00 mOhm, and 1255 = 12.55 mOhm. Range is 0-6249 (0-62.49 mOhms). 0 = AUTO/HW default. |
| `0x12B` | 2 | P-core | PS Current Threshold1 | 0..152 raw, pas 0,25 A (38 A max IFR); 0=AUTO/0 selon champ | 38 | 🔴 | ✅ IFR | PS Current Threshold1, defined in 1/4 A increments. A value of 400 = 100A. Range 0-152, which translates to 0-38A. 0 = AUTO. |
| `0x12D` | 2 | GT/iGPU | PS Current Threshold1 | 0..152 raw, pas 0,25 A (38 A max IFR); 0=AUTO/0 selon champ | 38 | 🔴 | ✅ IFR | PS Current Threshold1, defined in 1/4 A increments. A value of 400 = 100A. Range 0-152, which translates to 0-38A. 0 = AUTO. |
| `0x12F` | 2 | SA | PS Current Threshold1 | 0..152 raw, pas 0,25 A (38 A max IFR); 0=AUTO/0 selon champ | 38 | 🔴 | ✅ IFR | PS Current Threshold1, defined in 1/4 A increments. A value of 400 = 100A. Range 0-152, which translates to 0-38A. 0 = AUTO. |
| `0x131` | 2 | E-core | PS Current Threshold1 | 0..152 raw, pas 0,25 A (38 A max IFR); 0=AUTO/0 selon champ | 38 | 🔴 | ✅ IFR | PS Current Threshold1, defined in 1/4 A increments. A value of 400 = 100A. Range 0-152, which translates to 0-38A. 0 = AUTO. |
| `0x133` | 2 | L2 | PS Current Threshold1 | 0..48 raw, pas 0,25 A (12 A max IFR); 0=AUTO/0 selon champ | 12 | 🔴 | ✅ IFR | PS Current Threshold1, defined in 1/4 A increments. A value of 400 = 100A. Range 0-152, which translates to 0-38A. 0 = AUTO. |
| `0x137` | 2 | P-core | PS Current Threshold2 | 0..48 raw, pas 0,25 A (12 A max IFR); 0=AUTO/0 selon champ | 12 | 🔴 | ✅ IFR | PS Current Threshold2, defined in 1/4 A increments. A value of 400 = 100A. Range 0-48, which translates to 0-12A.Make sure PS2<=PS1. 0 = AUTO. |
| `0x139` | 2 | GT/iGPU | PS Current Threshold2 | 0..48 raw, pas 0,25 A (12 A max IFR); 0=AUTO/0 selon champ | 12 | 🔴 | ✅ IFR | PS Current Threshold2, defined in 1/4 A increments. A value of 400 = 100A. Range 0-48, which translates to 0-12A.Make sure PS2<=PS1. 0 = AUTO. |
| `0x13B` | 2 | SA | PS Current Threshold2 | 0..48 raw, pas 0,25 A (12 A max IFR); 0=AUTO/0 selon champ | 12 | 🔴 | ✅ IFR | PS Current Threshold2, defined in 1/4 A increments. A value of 400 = 100A. Range 0-48, which translates to 0-12A.Make sure PS2<=PS1. 0 = AUTO. |
| `0x13D` | 2 | E-core | PS Current Threshold2 | 0..48 raw, pas 0,25 A (12 A max IFR); 0=AUTO/0 selon champ | 12 | 🔴 | ✅ IFR | PS Current Threshold2, defined in 1/4 A increments. A value of 400 = 100A. Range 0-48, which translates to 0-12A.Make sure PS2<=PS1. 0 = AUTO. |
| `0x13F` | 2 | L2 | PS Current Threshold2 | 0..48 raw, pas 0,25 A (12 A max IFR); 0=AUTO/0 selon champ | 0 | 🔴 | ✅ IFR | PS Current Threshold2, defined in 1/4 A increments. A value of 400 = 100A. Range 0-48, which translates to 0-12A.Make sure PS2<=PS1. 0 = AUTO. |
| `0x143` | 2 | P-core | PS Current Threshold3 | 0..16 raw, pas 0,25 A (4 A max IFR); 0=AUTO/0 selon champ | 4 | 🔴 | ✅ IFR | PS Current Threshold3, defined in 1/4 A increments. A value of 400 = 100A. Range 0-16, which translates to 0-4A.Make sure PS3<=PS2. 0 = AUTO. |
| `0x145` | 2 | GT/iGPU | PS Current Threshold3 | 0..16 raw, pas 0,25 A (4 A max IFR); 0=AUTO/0 selon champ | 4 | 🔴 | ✅ IFR | PS Current Threshold3, defined in 1/4 A increments. A value of 400 = 100A. Range 0-16, which translates to 0-4A.Make sure PS3<=PS2. 0 = AUTO. |
| `0x147` | 2 | SA | PS Current Threshold3 | 0..16 raw, pas 0,25 A (4 A max IFR); 0=AUTO/0 selon champ | 4 | 🔴 | ✅ IFR | PS Current Threshold3, defined in 1/4 A increments. A value of 400 = 100A. Range 0-16, which translates to 0-4A.Make sure PS3<=PS2. 0 = AUTO. |
| `0x149` | 2 | E-core | PS Current Threshold3 | 0..16 raw, pas 0,25 A (4 A max IFR); 0=AUTO/0 selon champ | 4 | 🔴 | ✅ IFR | PS Current Threshold3, defined in 1/4 A increments. A value of 400 = 100A. Range 0-16, which translates to 0-4A.Make sure PS3<=PS2. 0 = AUTO. |
| `0x14B` | 2 | L2 | PS Current Threshold3 | 0..16 raw, pas 0,25 A (4 A max IFR); 0=AUTO/0 selon champ | 0 | 🔴 | ✅ IFR | PS Current Threshold3, defined in 1/4 A increments. A value of 400 = 100A. Range 0-16, which translates to 0-4A.Make sure PS3<=PS2. 0 = AUTO. |
| `0x14F` | 1 | P-core | PSI3 Enable | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🟡 | ✅ IFR | PSI3 Enable/Disable. 0 - Disabled, 1 - Enabled. |
| `0x150` | 1 | GT/iGPU | PSI3 Enable | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🟡 | ✅ IFR | PSI3 Enable/Disable. 0 - Disabled, 1 - Enabled. |
| `0x151` | 1 | SA | PSI3 Enable | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🟡 | ✅ IFR | PSI3 Enable/Disable. 0 - Disabled, 1 - Enabled. |
| `0x152` | 1 | E-core | PSI3 Enable | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🟡 | ✅ IFR | PSI3 Enable/Disable. 0 - Disabled, 1 - Enabled. |
| `0x153` | 1 | L2 | PSI3 Enable | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🟡 | ✅ IFR | PSI3 Enable/Disable. 0 - Disabled, 1 - Enabled. |
| `0x154` | 1 | VDDQ | PSI3 Enable | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🟡 | ✅ IFR | PSI3 Enable/Disable. 0 - Disabled, 1 - Enabled. |
| `0x155` | 1 | P-core | PSI4 Enable | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🟡 | ✅ IFR | PSI4 Enable/Disable. 0 - Disabled, 1 - Enabled. |
| `0x156` | 1 | GT/iGPU | PSI4 Enable | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🟡 | ✅ IFR | PSI4 Enable/Disable. 0 - Disabled, 1 - Enabled. |
| `0x157` | 1 | SA | PSI4 Enable | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🟡 | ✅ IFR | PSI4 Enable/Disable. 0 - Disabled, 1 - Enabled. |
| `0x158` | 1 | E-core | PSI4 Enable | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🟡 | ✅ IFR | PSI4 Enable/Disable. 0 - Disabled, 1 - Enabled. |
| `0x159` | 1 | L2 | PSI4 Enable | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🟡 | ✅ IFR | PSI4 Enable/Disable. 0 - Disabled, 1 - Enabled. |
| `0x15A` | 1 | VDDQ | PSI4 Enable | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🟡 | ✅ IFR | PSI4 Enable/Disable. 0 - Disabled, 1 - Enabled. |
| `0x15B` | 2 | P-core | IMON Slope | 0..1999 raw /1000; 0=AUTO | 0 | 🔴 | ✅ IFR | IMON Slope defined in 1/1000 increments. Range is 0-1999. For a 1.25 slope, enter 1250. 0 = AUTO. |
| `0x15D` | 2 | GT/iGPU | IMON Slope | 0..1999 raw /1000; 0=AUTO | 0 | 🔴 | ✅ IFR | IMON Slope defined in 1/1000 increments. Range is 0-1999. For a 1.25 slope, enter 1250. 0 = AUTO. |
| `0x15F` | 2 | SA | IMON Slope | 0..1999 raw /1000; 0=AUTO | 0 | 🔴 | ✅ IFR | IMON Slope defined in 1/1000 increments. Range is 0-1999. For a 1.25 slope, enter 1250. 0 = AUTO. |
| `0x161` | 2 | E-core | IMON Slope | 0..1999 raw /1000; 0=AUTO | 0 | 🔴 | ✅ IFR | IMON Slope defined in 1/1000 increments. Range is 0-1999. For a 1.25 slope, enter 1250. 0 = AUTO. |
| `0x163` | 2 | L2 | IMON Slope | 0..1999 raw /1000; 0=AUTO | 0 | 🔴 | ✅ IFR | IMON Slope defined in 1/1000 increments. Range is 0-1999. For a 1.25 slope, enter 1250. 0 = AUTO. |
| `0x165` | 2 | VDDQ | IMON Slope | 0..1999 raw /1000; 0=AUTO | 0 | 🔴 | ✅ IFR | IMON Slope defined in 1/1000 increments. Range is 0-1999. For a 1.25 slope, enter 1250. 0 = AUTO. |
| `0x167` | 4 | P-core | IMON Offset | 0..128000 raw /1000 | 0 | 🔴 | ✅ IFR | IMON Offset defined in 1/1000 increments. Range is 0-128000. For an offset of 25.348, enter 25348. |
| `0x16B` | 4 | GT/iGPU | IMON Offset | 0..128000 raw /1000 | 0 | 🔴 | ✅ IFR | IMON Offset defined in 1/1000 increments. Range is 0-128000. For an offset of 25.348, enter 25348. |
| `0x16F` | 4 | SA | IMON Offset | 0..128000 raw /1000 | 0 | 🔴 | ✅ IFR | IMON Offset defined in 1/1000 increments. Range is 0-128000. For an offset of 25.348, enter 25348. |
| `0x173` | 4 | E-core | IMON Offset | 0..128000 raw /1000 | 0 | 🔴 | ✅ IFR | IMON Offset defined in 1/1000 increments. Range is 0-128000. For an offset of 25.348, enter 25348. |
| `0x177` | 4 | L2 | IMON Offset | 0..128000 raw /1000 | 0 | 🔴 | ✅ IFR | IMON Offset defined in 1/1000 increments. Range is 0-128000. For an offset of 25.348, enter 25348. |
| `0x17B` | 4 | VDDQ | IMON Offset | 0..128000 raw /1000 | 0 | 🔴 | ✅ IFR | IMON Offset defined in 1/1000 increments. Range is 0-128000. For an offset of 25.348, enter 25348. |
| `0x17F` | 1 | P-core | IMON Prefix | 0 + (def) · 1 - | 0 (+) | 🔴 | ✅ IFR | Sets the offset value as positive or negative. |
| `0x180` | 1 | GT/iGPU | IMON Prefix | 0 + (def) · 1 - | 0 (+) | 🔴 | ✅ IFR | Sets the offset value as positive or negative. |
| `0x181` | 1 | SA | IMON Prefix | 0 + (def) · 1 - | 0 (+) | 🔴 | ✅ IFR | Sets the offset value as positive or negative. |
| `0x182` | 1 | E-core | IMON Prefix | 0 + (def) · 1 - | 0 (+) | 🔴 | ✅ IFR | Sets the offset value as positive or negative. |
| `0x183` | 1 | L2 | IMON Prefix | 0 + (def) · 1 - | 0 (+) | 🔴 | ✅ IFR | Sets the offset value as positive or negative. |
| `0x184` | 1 | VDDQ | IMON Prefix | 0 + (def) · 1 - | 0 (+) | 🔴 | ✅ IFR | Sets the offset value as positive or negative. |
| `0x185` | 2 | P-core | VR Current Limit | 0..1023 raw, pas 0,25 A (255.75 A max IFR); 0=AUTO/0 selon champ | 0 | 🔴 | 👀 IFR + lecture live | Voltage Regulator Current Limit (Icc Max). This value represents the Maximum instantaneous current allowed at any given time. The value is represented in 1/4 A increments. A value of 400 = 100A. 0 means AUTO. |
| `0x187` | 2 | GT/iGPU | VR Current Limit | 0..1023 raw, pas 0,25 A (255.75 A max IFR); 0=AUTO/0 selon champ | 0 | 🔴 | 👀 IFR + lecture live | Voltage Regulator Current Limit (Icc Max). This value represents the Maximum instantaneous current allowed at any given time. The value is represented in 1/4 A increments. A value of 400 = 100A. 0 means AUTO. |
| `0x189` | 2 | SA | VR Current Limit | 0..1023 raw, pas 0,25 A (255.75 A max IFR); 0=AUTO/0 selon champ | 0 | 🔴 | 👀 IFR + lecture live | Voltage Regulator Current Limit (Icc Max). This value represents the Maximum instantaneous current allowed at any given time. The value is represented in 1/4 A increments. A value of 400 = 100A. 0 means AUTO. |
| `0x18B` | 2 | E-core | VR Current Limit | 0..1023 raw, pas 0,25 A (255.75 A max IFR); 0=AUTO/0 selon champ | 0 | 🔴 | 👀 IFR + lecture live | Voltage Regulator Current Limit (Icc Max). This value represents the Maximum instantaneous current allowed at any given time. The value is represented in 1/4 A increments. A value of 400 = 100A. 0 means AUTO. |
| `0x191` | 2 | P-core | TDC Chosen Mode Current Limit | 0..32767 raw, pas 0,125 A (4095.88 A max IFR) | 0 | 🔴 | ✅ IFR | VR TDC Chosen Mode Current Limit, defined in 1/8A increments. Range 0-32767. For a TDC Current Limit of 125A, enter 1000. 0 = 0 Amps. |
| `0x193` | 2 | GT/iGPU | TDC Chosen Mode Current Limit | 0..32767 raw, pas 0,125 A (4095.88 A max IFR) | 0 | 🔴 | ✅ IFR | VR TDC Chosen Mode Current Limit, defined in 1/8A increments. Range 0-32767. For a TDC Current Limit of 125A, enter 1000. 0 = 0 Amps. |
| `0x195` | 2 | SA | TDC Chosen Mode Current Limit | 0..32767 raw, pas 0,125 A (4095.88 A max IFR) | 0 | 🔴 | ✅ IFR | VR TDC Chosen Mode Current Limit, defined in 1/8A increments. Range 0-32767. For a TDC Current Limit of 125A, enter 1000. 0 = 0 Amps. |
| `0x197` | 2 | E-core | TDC Chosen Mode Current Limit | 0..32767 raw, pas 0,125 A (4095.88 A max IFR) | 0 | 🔴 | ✅ IFR | VR TDC Chosen Mode Current Limit, defined in 1/8A increments. Range 0-32767. For a TDC Current Limit of 125A, enter 1000. 0 = 0 Amps. |
| `0x19D` | 1 | P-core | TDC Enable | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🔴 | ✅ IFR | VR TDC Enable. 0- Disable, 1 - Enable |
| `0x19E` | 1 | GT/iGPU | TDC Enable | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🔴 | ✅ IFR | VR TDC Enable. 0- Disable, 1 - Enable |
| `0x19F` | 1 | SA | TDC Enable | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🔴 | ✅ IFR | VR TDC Enable. 0- Disable, 1 - Enable |
| `0x1A0` | 1 | E-core | TDC Enable | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🔴 | ✅ IFR | VR TDC Enable. 0- Disable, 1 - Enable |
| `0x1A3` | 4 | P-core | TDC Time Window | 0 Auto · 1000=1 s … 448000=448 s | 0 (Auto) | 🔴 | ✅ IFR | VR TDC Time Window, value in seconds. Auto = 0. Range from 1s to 448s. |
| `0x1A7` | 4 | GT/iGPU | TDC Time Window | 0 Auto · 1000=1 s … 448000=448 s | 0 (Auto) | 🔴 | ✅ IFR | VR TDC Time Window, value in seconds. Auto = 0. Range from 1s to 448s. |
| `0x1AB` | 4 | SA | TDC Time Window | 0 Auto · 1000=1 s … 448000=448 s | 0 (Auto) | 🔴 | ✅ IFR | VR TDC Time Window, value in seconds. Auto = 0. Range from 1s to 448s. |
| `0x1AF` | 4 | E-core | TDC Time Window | 0 Auto · 1000=1 s … 448000=448 s | 0 (Auto) | 🔴 | ✅ IFR | VR TDC Time Window, value in seconds. Auto = 0. Range from 1s to 448s. |
| `0x1BB` | 1 | P-core | TDC Lock | 0 Disabled (def) · 1 Enabled | 0 (Disabled) | 🔴 | ✅ IFR | VR TDC Lock |
| `0x1BC` | 1 | GT/iGPU | TDC Lock | 0 Disabled (def) · 1 Enabled | 0 (Disabled) | 🔴 | ✅ IFR | VR TDC Lock |
| `0x1BD` | 1 | SA | TDC Lock | 0 Disabled (def) · 1 Enabled | 0 (Disabled) | 🔴 | ✅ IFR | VR TDC Lock |
| `0x1BE` | 1 | E-core | TDC Lock | 0 Disabled (def) · 1 Enabled | 0 (Disabled) | 🔴 | ✅ IFR | VR TDC Lock |
| `0x1CB` | 1 |  | Tcc Offset Clamp Enable | 0 Disabled (def) · 1 Enabled | 0 (Disabled) | 🔴 | ✅ IFR | Tcc Offset Clamp bit Enable for Running Average Temperature Limit(RATL) feature to allow CPU to throttle below P1. |
| `0x1CC` | 1 |  | Tcc Offset Lock Enable | 0 Disabled (def) · 1 Enabled (def) | 0 (Disabled), 1 (Enabled) | 🔴 | ✅ IFR | Lock Enable for Running Average Temperature Limit(RATL) feature to lock Temperature Target MSR. |
| `0x1CD` | 2 |  | IMON Slope VDD2H | 0..200 raw /100; 0=AUTO | 0 | 🔴 | ✅ IFR | IMON Slope defined in 1/100 increments. Range is 0-200. For a 1.25 slope, enter 125. 0 = AUTO. |
| `0x1CF` | 4 |  | IMON Offset VDD2H | 0..63999 raw /1000 | 0 | 🔴 | ✅ IFR | IMON Offset defined in 1/1000 increments. Range is 0-63999. For an offset of 25.348, enter 25348. |
| `0x1D3` | 2 |  | IMON Slope VDD2L | 0..200 raw /100; 0=AUTO | 0 | 🔴 | ✅ IFR | IMON Slope defined in 1/100 increments. Range is 0-200. For a 1.25 slope, enter 125. 0 = AUTO. |
| `0x1D5` | 4 |  | IMON Offset VDD2L | 0..63999 raw /1000 | 0 | 🔴 | ✅ IFR | IMON Offset defined in 1/1000 increments. Range is 0-63999. For an offset of 25.348, enter 25348. |
| `0x1D9` | 2 |  | ISYS Current Limit L1 | 0..32767 raw, pas 0,125 A (4095.88 A max IFR) | 0 | 🔴 | ✅ IFR | This field indicated the current limitation of L1. Units of measurements are 1/8 A. For a 6.5 A, enter 52 (0x34). |
| `0x1DB` | 1 |  | ISYS Current Limit L1 Enable | 0 Disabled (def) · 1 Enabled | 0 (Disabled) | 🔴 | ✅ IFR | This bits enables disables ISYS_CURRENT_LIMIT_L1 algorithm |
| `0x1DC` | 1 |  | ISYS Current Limit L1 Tau | 0 0 (def) · 1 1 · 2 2 · 3 3 · 4 4 · 5 5 · 6 6 · 7 7 · 8 8 · 10 10 · 12 12 · 14 14 · … | 0 (0) | 🔴 | ✅ IFR | Isys L1 time window value in seconds. The value may vary from 0 to 128. 0 = default values. Specifies the time window used to calculate average current for ISYS_L1. |
| `0x1DD` | 2 |  | ISYS Current Limit L2 | 0..32767 raw, pas 0,125 A (4095.88 A max IFR) | 0 | 🔴 | ✅ IFR | This field indicated the current limitation of L2. Units of measurements are 1/8 A. For a 6.5 A, enter 52 (0x34). |
| `0x1DF` | 1 |  | ISYS Current Limit L2 Enable | 0 Disabled (def) · 1 Enabled | 0 (Disabled) | 🔴 | ✅ IFR | This bits enables disables ISYS_CURRENT_LIMIT_L2 algorithm |
| `0x1E0` | 1 |  | ThETA Ibatt Feature | 0 Disabled (def) · 1 Enabled | 0 (Disabled) | 🟡 | ✅ IFR | Enable/Disable ThETA Ibatt Feature |
| `0x1E1` | 2 |  | Vsys Max | 0..65535 raw /1000; 0=AUTO | 0 | 🔴 | ✅ IFR | Vsys Max defined in 1/1000 increments. Range is 0-65535. For a 1.25 voltage, enter 1250. 0 = AUTO. |
| `0x20F` | 1 |  | Acoustic Noise Mitigation | 0 Disabled (def) · 1 Enabled | 0 (Disabled) | 🟡 | ✅ IFR | Enabling this option will help mitigate acoustic noise on certain SKUs when the CPU is in deeper C state |
| `0x216` | 1 |  | Slow Slew Rate for Core Domain | 0 Fast/2 (def) · 1 Fast/4 | 0 (Fast/2) | 🟠 | ✅ IFR | Set VR Core Slow Slew Rate for Deep Package C State ramp time; Slow slew rate equals to Fast divided by number, the number is 2, 4, 8, 16 to slow down the slew rate to help minimize acoustic noise |
| `0x217` | 1 |  | Slow Slew Rate for GT Domain | 0 Fast/2 (def) · 1 Fast/4 · 2 Fast/8 | 0 (Fast/2) | 🟠 | ✅ IFR | Set VR GT Slow Slew Rate for Deep Package C State ramp time; Slow slew rate equals to Fast divided by number, the number is 2, 4, 8 to slow down the slew rate to help minimize acoustic noise; divide by 16 is disabled |
| `0x219` | 1 |  | Slow Slew Rate for ATOM Domain | 0 Fast/2 (def) · 1 Fast/4 | 0 (Fast/2) | 🟠 | ✅ IFR | Set VR ATOM Slow Slew Rate for Deep Package C State ramp time; Slow slew rate equals to Fast divided by number, the number is 2, 4, 8 to slow down the slew rate to help minimize acoustic noise; divide by 16 is disabled |
| `0x222` | 4 |  | BCLK RFI Frequency - SAGV Low | 4-byte IFR field; default 0; exact numeric range not promoted from current notes | 0 | 🟠 | ✅ IFR | Recovered BCLK RFI/SAGV frequency field; default 0. |
| `0x226` | 4 |  | BCLK RFI Frequency - SAGV Mid | 4-byte IFR field; default 0; exact numeric range not promoted from current notes | 0 | 🟠 | ✅ IFR | Recovered BCLK RFI/SAGV frequency field; default 0. |
| `0x22A` | 4 |  | BCLK RFI Frequency - SAGV High | 4-byte IFR field; default 0; exact numeric range not promoted from current notes | 0 | 🟠 | ✅ IFR | Recovered BCLK RFI/SAGV frequency field; default 0. |
| `0x22E` | 4 |  | BCLK RFI Frequency - SAGV Max | 4-byte IFR field; default 0; exact numeric range not promoted from current notes | 0 | 🟠 | ✅ IFR | Recovered BCLK RFI/SAGV frequency field; default 0. |
| `0x232` | 1 |  | BCLK Spread | 0 Disabled · 1 Enabled (default) | 1 (Enabled) | 🟠 | 🧪 testé | BCLK Spread Spectrum control; 0 Disabled, 1 Enabled. |
| `0x236` | 1 |  | Enable Configurable Base Power | 0 Applies to non-cTDP · 1 Applies to cTDP (def) | 1 (Applies to cTDP) | 🟠 | ✅ IFR | Applies Assured Power (cTDP) initialization settings based on non-Assured Power (cTDP) or Assured Power (cTDP). Default is 1: Applies to Assured Power (cTDP); if 0 then applies non-Assured Power (cTDP) and BIOS will bypass Assured Power (cTDP) initialization flow |
| `0x2FD` | 1 |  | DLVR SSC Value | 0 0% · 2 0.5% · 4 1% · 8 2% · 16 4% | 2 | 🟠 | ✅ IFR | DLVR SSC in percentage with multiple of 0.25%. 0 = 0%, 10 =4%. |
| `0x2FE` | 2 |  | DLVR RFI Frequency | 0 2227MHz · 1 2140MHz | 0 | 🟠 | ✅ IFR | DLVR RFI Frequency in MHz. |
| `0x300` | 1 |  | Global DLVR RFI Mitigation Control | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🟠 | ✅ IFR | Enable/Disable Global DLVR RFI Mitigation Control |
| `0x301` | 1 |  | DLVR PHASE_SSC | 0 Disabled (def) · 1 Enabled | 0 (Disabled) | 🟠 | ✅ IFR | Enable/Disable DLVR PHASE_SSC |
| `0x303` | 1 |  | CrashLog GPRs | 0..2 | — | 🟡 | ✅ IFR | Helps collecting crash data from PMC SSRAM. Enabling this may expose personal or confidential information that may be held in the GPRs at the time of the Crash trigger |
| `0x304` | 1 |  | Vsys/Psys Critical | 0 Disabled (def) · 1 Psys Critical · 2 Vsys Critical | 0 (Disabled) | 🔴 | ✅ IFR | Vsys/Psys Critical Enable or disable |
| `0x305` | 1 |  | Assertion Deglitch Mantissa | 0..255, step 1 | 1 | 🟡 | ✅ IFR | Assertion Deglitch Mantissa 0x4F[7-3]. Assertion Deglitch = 2µs * Mantissa * 2^(Exponent) |
| `0x306` | 1 |  | Assertion Deglitch Exponent | 0..255, step 1 | 0 | 🟡 | ✅ IFR | Assertion Deglitch Exponent 0x4F[3-0]. Assertion Deglitch = 2µs * Mantissa * 2^(Exponent) |
| `0x307` | 1 |  | De assertion Deglitch Mantissa | 0..255, step 1 | 13 | 🟡 | ✅ IFR | De Assertion Deglitch Mantissa 0x49[7-3]. Assertion Deglitch = 2µs * Mantissa * 2^(Exponent) |
| `0x308` | 1 |  | De assertion Deglitch Exponent | 0..255, step 1 | 2 | 🟡 | ✅ IFR | De Assertion Deglitch Exponent 0x49[3-0]. Assertion Deglitch = 2µs * Mantissa * 2^(Exponent) |
| `0x33A` | 1 |  | DFD Enable | 0..1 | — | 🟡 | ✅ IFR | When enabled, DFD power will keep up; when disabled, DFD power will shutdown |
| `0x33B` | 2 | P-core | VR Fast Vmode ICC Limit | 0..2040 raw, pas 0,25 A (510 A max IFR); 0=AUTO/0 selon champ | 0 | 🔴 | ✅ IFR | Voltage Regulator Fast Vmode ICC Limit. A value of 400 = 100A. This value represents the current threshold where the VR would initiate reactive protection if Fast Vmode is enabled. The value is represented in 1/4 A increments. |
| `0x33D` | 2 | GT/iGPU | VR Fast Vmode ICC Limit | 0..2040 raw, pas 0,25 A (510 A max IFR); 0=AUTO/0 selon champ | 0 | 🔴 | ✅ IFR | Voltage Regulator Fast Vmode ICC Limit. A value of 400 = 100A. This value represents the current threshold where the VR would initiate reactive protection if Fast Vmode is enabled. The value is represented in 1/4 A increments. |
| `0x33F` | 2 | SA | VR Fast Vmode ICC Limit | 0..2040 raw, pas 0,25 A (510 A max IFR); 0=AUTO/0 selon champ | 0 | 🔴 | ✅ IFR | Voltage Regulator Fast Vmode ICC Limit. A value of 400 = 100A. This value represents the current threshold where the VR would initiate reactive protection if Fast Vmode is enabled. The value is represented in 1/4 A increments. |
| `0x341` | 2 | E-core | VR Fast Vmode ICC Limit | 0..2040 raw, pas 0,25 A (510 A max IFR); 0=AUTO/0 selon champ | 0 | 🔴 | ✅ IFR | Voltage Regulator Fast Vmode ICC Limit. A value of 400 = 100A. This value represents the current threshold where the VR would initiate reactive protection if Fast Vmode is enabled. The value is represented in 1/4 A increments. |
| `0x343` | 2 | L2 | VR Fast Vmode ICC Limit | 0..2040 raw, pas 0,25 A (510 A max IFR); 0=AUTO/0 selon champ | 0 | 🔴 | ✅ IFR | Voltage Regulator Fast Vmode ICC Limit. A value of 400 = 100A. This value represents the current threshold where the VR would initiate reactive protection if Fast Vmode is enabled. The value is represented in 1/4 A increments. |
| `0x345` | 2 | VDDQ | VR Fast Vmode ICC Limit | 0..2040 raw, pas 0,25 A (510 A max IFR); 0=AUTO/0 selon champ | 0 | 🔴 | ✅ IFR | Voltage Regulator Fast Vmode ICC Limit. A value of 400 = 100A. This value represents the current threshold where the VR would initiate reactive protection if Fast Vmode is enabled. The value is represented in 1/4 A increments. |
| `0x348` | 1 | P-core | Core VR Fast Vmode | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🔴 | ✅ IFR | Core VR Fast Vmode. Use to control Core Fast Vmode Enable/Disable. |
| `0x349` | 1 | GT/iGPU | GT VR Fast Vmode | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🔴 | ✅ IFR | GT VR Fast Vmode. Use to control GT Fast Vmode Enable/Disable. |
| `0x34A` | 1 | SA | SA VR Fast Vmode | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🔴 | ✅ IFR | SA VR Fast Vmode. Use to control SA Fast Vmode Enable/Disable. |
| `0x351` | 4 |  | Vsys/Psys Full Scale | 0..255000, step 1 | 24000 | 🔴 | ✅ IFR | Input Vsys/Psys Full Scale and Critical Threshold to program Vsys/Psys Critical(0x4A). Vsys/Psys Critical = (Critical Threshold/Full Scale) * 0xFF, Input is in mVolts. |
| `0x355` | 4 |  | Vsys/Psys Critical Threshold | 0..255000 % | 6000 | 🔴 | ✅ IFR | en-US “Input Vsys/Psys Full Scale & Critical Threshold. Vsys/Psys Critical = (Critical Threshold/Full Scale). Vsys input is in mVolts. Psys input is in mW or in m% (for ATX12VO) |
| `0x359` | 4 |  | Vsys/Psys Full Scale | 0..255000, step 1 | 200000 | 🔴 | ✅ IFR | Input Vsys/Psys Full Scale and Critical Threshold to program Vsys/Psys Critical(0x4A). Vsys/Psys Critical = (Critical Threshold/Full Scale) * 0xFF, Input is in mVolts. |
| `0x35D` | 4 |  | Vsys/Psys Critical Threshold | 0..255000 % | 130000 | 🔴 | ✅ IFR | en-US “Input Vsys/Psys Full Scale & Critical Threshold. Vsys/Psys Critical = (Critical Threshold/Full Scale). Vsys input is in mVolts. Psys input is in mW or in m% (for ATX12VO) |
| `0x3D8` | 1 |  | PROCHOT Demotion | 0 Disabled · 1 Hardware Default (def) | 1 (Hardware Default) | 🔴 | ✅ IFR | PROCHOT Demotion Algorithm. PROCHOT Demotion Algorithm will limit the frequency to a lower point gradually instead of limiting to LFM immediately. Disable means BIOS provides the capability to disable it via pcode mailbox. Hardware Default means BIOS do nothing, thus keep Prochot Demotion Algorithm in hardware default status. |
| `0x3D9` | 1 |  | VrAlert Demotion | 0 Disabled · 1 Enabled (def) | 1 (Enabled) | 🔴 | 🧰 IFR + script | VrAlert Demotion Algorithm. VrAlert Demotion Algorithm will help by lowering the corresponding domain to lower frequency and potentially lowering voltage of the VR. Disable means BIOS provides the capability to disable it via pcode mailbox. |
| `0x3E0` | 1 |  | VDD2L Prefix | 0 + (def) · 1 - | 0 (+) | 🟡 | ✅ IFR | Sets the offset value as positive or negative. |
| `0x3E1` | 1 |  | VDD2H Prefix | 0 + (def) · 1 - | 0 (+) | 🟡 | ✅ IFR | Sets the offset value as positive or negative. |
| `0x3E7` | 1 |  | Skin Control Temperature Enable MMIO | 0 Disabled (def) · 1 Enabled | 0 (Disabled) | 🟡 | ✅ IFR | Enables the skin temperature control for MMIO register. |
| `0x3EA` | 1 |  | Skin Temperature Loop Gain | 0..7, step 1 | 0 | 🔴 | ✅ IFR | Sets the aggressiveness of control loop where 0 – graceful, favors performance on expense of temperature overshoots and 7 – aggressive, favors tight regulation over performance. Range is 0-7 |
| `0x3ED` | 1 |  | Skin Temperature Override Enable | 0 Disabled (def) · 1 Enabled | 0 (Disabled) | 🔴 | ✅ IFR | When set, Pcode will use TEMPERATURE_OVERRIDE values instead of reading from corresponding sensor. |
| `0x3F0` | 1 |  | Skin Temperature Minimum Performance Level | 0..255, step 1 | 0 | 🔴 | ✅ IFR | Minimum Performance level below which the STC limit will not throttle. 0 - all levels of throttling allowed incl. survivability actions. 256 - no throttling allowed |
| `0x3F3` | 1 |  | Skin Temperature Override | 0..255, step 1 | 0 | 🔴 | ✅ IFR | Allows SW to override the input temperature. Pcode will use this value instead of the sensor temperature. EC control is not impacted. Units: 0.5C. Values are 0 to 255 which represents 0C-122.5C range |
| `0x44A` | 1 | P-core | TDC Mode | 0 iPL2 · 1 IRMS | — | 🔴 | ✅ IFR | VR TDC Mode Based on IRMS_Supported bit from Mailbox, 0 = iPL2 and 1 = IRMS |
| `0x44B` | 1 | GT/iGPU | TDC Mode | 0 iPL2 · 1 IRMS | — | 🔴 | ✅ IFR | VR TDC Mode Based on IRMS_Supported bit from Mailbox, 0 = iPL2 and 1 = IRMS |
| `0x44C` | 1 | SA | TDC Mode | 0 iPL2 · 1 IRMS | — | 🔴 | ✅ IFR | VR TDC Mode Based on IRMS_Supported bit from Mailbox, 0 = iPL2 and 1 = IRMS |
| `0x44D` | 1 | E-core | TDC Mode | 0 iPL2 · 1 IRMS | — | 🔴 | ✅ IFR | VR TDC Mode Based on IRMS_Supported bit from Mailbox, 0 = iPL2 and 1 = IRMS |
| `0x456` | 1 |  | Pcore Hysteresis Window | 0..50 ms | 0 | 🟡 | ✅ IFR | Set the Hysteresis time in miliseconds. Range is 0-50ms. Pcode will clip any number above max and return success |
| `0x457` | 1 |  | Ecore Hysteresis Window | 0..50 ms | 0 | 🟡 | ✅ IFR | Set the Hysteresis time in miliseconds. Range is 0-50ms. Pcode will clip any number above max and return success |
## Known fields outside the named IFR table

The `0x2F3/0x2F4/0x2F5` early-policy bytes are intentionally not inserted into the IFR table because their **names and semantics are not recovered from IFR**. They remain read-only reverse candidates documented above and in `UNDERVOLT-REVERSE.md`.

## What is still unknown

- the exact earliest Lenovo policy source that turns runtime UVP on/locks the write path even though static `FSPM +0x896` is zero;
- the exact EC/PMC/Pcode branch that derives the RSOC-dependent reactive electrical limit;
- a safe signed firmware modification that disables UVP before the PCODE lock without breaking firmware integrity/boot;
- Lunar Lake write semantics for the legacy undervolt planes other than Core/IA and Ring/Cache;
- whether additional DLVR/RFI tuning provides any measurable performance benefit on this laptop.

Those unknowns are deliberately left as unknowns rather than converted into speculative write scripts.
