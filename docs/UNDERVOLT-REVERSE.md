# Lunar Lake undervolt / UVP reverse

The undervolt work is split into three independent problems: clearing the normal OC lock, understanding/clearing **Undervolt Protection (UVP)**, and finally issuing a voltage offset through Intel's OC mailbox.

## Current result in one line

**OC Lock can be cleared; UVP cannot yet be cleared.** The voltage-offset tool is implemented and ready, but it deliberately refuses writes while UVP is active.

## 1. Normal OC lock

The IFR exposes:

```text
CpuSetup + 0xFA, 1 byte: Overclocking Lock
```

Clearing it with `Yoga14ILL10-Undervolt-OC-Lock.nsh` produced the observed state:

```text
MSR 0x194 = 0x0000000000010000
MSR 0x195 = 0x0000000000000002
```

Interpretation used by the tools:

```text
MSR 0x194 bit20 = 0   -> observed OC Lock cleared
MSR 0x195 bit1  = 1   -> Undervolt Protection active
MSR 0x195 bit2  = 0   -> OC Secure clear
```

This proves that the regular OC lock and UVP are separate states on the tested system.

VT-x was disabled independently (`vmx` absent and the tested IA32_FEATURE_CONTROL state did not expose an active VMX configuration), but UVP remained set. VT-x is therefore not the source of the observed UVP state.

## 2. Voltage-offset path: MSR 0x150

`tools/lnl-undervolt` implements the Intel OC mailbox path:

```text
MSR 0x150
command 0x10 -> read voltage offset
command 0x11 -> write voltage offset
```

The command encoding carries a voltage plane and an 11-bit signed offset in 1/1024 V units. On Lunar Lake model `0xBD`, this repository allows **writes only** to the two domains whose use is supported by the recovered firmware path:

```text
plane 0 -> Core / IA
plane 2 -> Ring / Cache
```

Other legacy plane IDs remain readable/encodable for research but are not enabled for writes because their Lunar Lake semantics are not proven.

The tool intentionally enforces:

- undervolt only, never positive voltage;
- `-100 .. 0 mV` software limit;
- refuse while UVP is set;
- refuse while the observed OC Lock is set;
- read-back verification after a write.

Therefore the software side is ready, but the live machine cannot yet use `set` because UVP remains active.

## 3. PCODE UVP interface

MCHBAR is recovered from PCI `0000:00:00.0`, config offset `0x48`. The PCODE mailbox used by the UVP probes is:

```text
DATA      = MCHBAR + 0x5DA0
INTERFACE = MCHBAR + 0x5DA4
RUN/BUSY  = bit31
```

The discovered OC interface uses:

```text
command 0x37
subcommand 0x16 -> read UnderVoltProtection
subcommand 0x17 -> write UnderVoltProtection
DATA=0          -> request UVP off
completion 0x06 -> PCODE_LOCKED
```

The read path works and reports UVP active. The disable write was tested at several timings:

```text
Linux runtime          -> PCODE_LOCKED
normal UEFI app        -> PCODE_LOCKED
BDS Driver#### one-shot -> PCODE_LOCKED
```

This shows that moving the same write from Linux into a normal UEFI application or a BDS driver is still too late.

## 4. Raw FSP PCODE 0x48 path

Reverse engineering of the exact `SiInitPreMemFsp` image recovered an earlier path:

```text
if (internal_policy[0x13B] != 0) {
    PCODE command = 0x48
    DATA = 1
}
```

`internal_policy + 0x13B` is fed from `FSPM_UPD + 0x896` by `FspInitPreMem`.

A narrow UEFI test tried the inferred symmetric operation:

```text
PCODE 0x48
DATA  = 0
```

That path was also already `PCODE_LOCKED` by normal UEFI-application time. The operation is an inference from the exact firmware code; it is not claimed as a public Intel API.

## 5. Exact FSP-M / LNLUPD_M mapping

The analyzed ROM is:

```text
KLS71_sign.rom
SHA256 21ff6995dc89ee637aceba0f0c37aa9b3b04292d04b8fe7240e512a7874c86bd
```

Two real duplicated `LNLUPD_M` structures were located at:

```text
file + 0x00D56764
file + 0x01156764
```

The important recovered values are identical in both:

```text
+0x884 = 0x02
+0x885 = 0x01
+0x886 = 0x00
+0x887 = 0x00
+0x888 = 0x00
+0x896 = 0x00  UnderVoltProtection input
+0x897 = 0x00  adjacent / EnableVsysCritical path
+0x898 = 24000
+0x89C = 6000
+0x8A0 = 200000
+0x8A4 = 130000
```

`FspInitPreMem` mapping recovered from the exact TE image:

```text
FSPM +0x884 -> internal CPU policy +0x0F7
FSPM +0x885 -> internal CPU policy +0x0F8
FSPM +0x886 -> internal CPU policy +0x0F9   CONFIRMED
FSPM +0x887 -> internal CPU policy +0x0FA   CONFIRMED
FSPM +0x888 -> internal CPU policy +0x0FB   CONFIRMED
FSPM +0x896 -> internal CPU policy +0x13B   CONFIRMED
FSPM +0x897 -> internal CPU policy +0x160
```

The crucial contradiction is that **the static `+0x896` byte is already zero**, while the running processor reports `MSR 0x195 bit1 = 1`. A ROM patch that merely changes `+0x896` to zero would therefore change nothing. Some earlier policy source, override, or Pcode state still results in UVP being active/locked.

## 6. Early PCODE command 0x0A

`SiInitPreMemFsp` also packs internal CPU-policy bytes `+0xF9/+0xFA/+0xFB` into the payload of an early raw PCODE command `0x0A`:

```text
DATA = policy[0xF9]
     | policy[0xFA] << 8
     | policy[0xFB] << 16
```

A separate Lenovo-wrapper reverse produced the read-only candidate mapping:

```text
CpuSetup +0x2F3 -> early policy byte corresponding to +0xF9
CpuSetup +0x2F4 -> early policy byte corresponding to +0xFA
CpuSetup +0x2F5 -> early policy byte corresponding to +0xFB
```

These three `CpuSetup` bytes are **unnamed hidden fields** and their semantic meaning is not proven from IFR. They must not be confused with:

```text
CpuSetup +0xFA = Overclocking Lock
CpuSetup +0xFB = CPU Run Control
CpuSetup +0xFC = CPU Run Control Lock
```

`Yoga14ILL10-UVP-PCODE0A-audit.nsh` is intentionally read-only. No repository script writes `0x2F3..0x2F5`.

## 7. What the lock timing tells us

These states have been observed together:

```text
OC Lock   = 0
OC Secure = 0
UVP       = 1
0x37/0x17 DATA=0 -> PCODE_LOCKED
raw 0x48 DATA=0  -> PCODE_LOCKED
```

The remaining viable investigation point is **earlier than normal UEFI/BDS**: PEI/FSP initialization or the platform code that constructs the policy before the lock is asserted. This is why the repository contains `tools/analyze-lnl-fspm-uvp` rather than pretending that a flashable UVP-off ROM has already been solved.

## Active tools

| Path | Purpose |
|---|---|
| `tools/lnl-undervolt/` | MSR `0x150` voltage read/write utility with UVP/OC-lock guards |
| `tools/lnl-uvp-pcode/` | live MCHBAR/PCODE UVP reader and narrow retest path |
| `tools/analyze-lnl-fspm-uvp/` | read-only ROM/FSP-M mapping and disassembly helper |

The normal UEFI app, BDS `Driver####` and inferred raw `0x48 DATA=0` experiments were useful to establish the lock timing, but their dedicated test programs are no longer kept in the active repository. Their confirmed results remain documented above.

Generated executables are intentionally not committed; build the active tools locally from source.
