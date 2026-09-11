# KLS71 Lunar Lake UVP policy mapper

Read-only offline reverse-engineering helper for the Lenovo Yoga Slim 7
14ILL10 (83JX), exact `KLS71_sign.rom`.

This tool exists because the live experiments established that all of these
states can coexist:

```text
OC Lock = 0
OC Secure = 0
UVP = 1
PCODE 0x37/0x17 DATA=0 -> PCODE_LOCKED
raw PCODE 0x48 DATA=0  -> PCODE_LOCKED
```

A normal UEFI application and a `Driver####` entry are therefore already too
late. Before editing PEI/FSP code protected by firmware integrity mechanisms,
the next job is to map the early FSP-M policy precisely.

## What the analyzer checks

It:

- SHA256-checks the ROM against the exact known KLS71 image;
- locates the duplicated real `LNLUPD_M` structures;
- dumps the fields around `+0x886..+0x8A4`;
- verifies the `FspInitPreMem` copy chain:
  - `FSPM +0x886 -> policy +0xF9`
  - `FSPM +0x887 -> policy +0xFA`
  - `FSPM +0x888 -> policy +0xFB`
  - `FSPM +0x896 -> CPU_PM_VR_CONFIG +0x13B` (**DLVR PHASE_SSC, not UVP**)
- extracts the early `SiInitPreMemFsp` contexts where policy bytes
  `+0xF9/+0xFA/+0xFB` are packed into PCODE command `0x0A`;
- extracts the early UVP/PCODE `0x48` context;
- optionally cross-references the known `CpuSetup` IFR CSV.

It does **not** modify the ROM, NVRAM, MSRs or MMIO.

## Exact known ROM

```text
KLS71_sign.rom
SHA256 21ff6995dc89ee637aceba0f0c37aa9b3b04292d04b8fe7240e512a7874c86bd
```

The two known real FSPM UPD blobs are at:

```text
0x00D56764
0x01156764
```

and `+0x896` is already zero in both.

## Usage

From the repository:

```bash
python3 tools/analyze-lnl-fspm-uvp/kls71-uvp-policy-map.py \
  --rom ~/bios-lenovo/KLS71_sign.rom \
  --fsp-init-disasm ~/bios-lenovo/FspInitPreMem.disasm.txt \
  --si-init-disasm ~/bios-lenovo/SiInitPreMemFsp.disasm.txt \
  --cpu-csv ~/bios-lenovo/cpusetup-variables.csv \
  --json /tmp/kls71-uvp-policy-map.json \
  | tee /tmp/kls71-uvp-policy-map.txt
```

Adjust paths to where the extraction/disassemblies actually live.

The ROM alone is enough to dump FSPM values:

```bash
python3 tools/analyze-lnl-fspm-uvp/kls71-uvp-policy-map.py \
  --rom /path/to/KLS71_sign.rom
```

## Important distinction

Do **not** infer:

```text
FSPM +0x887 == CpuSetup +0xFA
FSPM +0x888 == CpuSetup +0xFB
```

from the numeric similarity.

The verified mapping is between **FSPM UPD offsets** and **Intel internal CPU
policy offsets**. The Lenovo `CpuSetup` -> FSPM UPD mapping still has to be
proven independently in the Lenovo pre-memory wrapper/policy modules.

That is the mapping needed before a safe `setup_var.efi` experiment can be
designed.


## Automatic disassembly from UEFIExtract

The analyzer no longer requires pre-generated `.disasm.txt` files.

If this directory exists next to the ROM:

```text
KLS71_sign.rom.dump/
```

it is detected automatically. Otherwise pass it explicitly:

```bash
python3 tools/analyze-lnl-fspm-uvp/kls71-uvp-policy-map.py \
  --rom ~/bios-lenovo/KLS71_sign.rom \
  --dump-root ~/bios-lenovo/KLS71_sign.rom.dump \
  --cpu-csv ~/bios-lenovo/cpusetup-variables.csv \
  --json /tmp/kls71-uvp-policy-map.json \
  | tee /tmp/kls71-uvp-policy-map.txt
```

For the exact KLS71 TE images, the tool reconstructs the `.text` stream directly
from UEFIExtract's `TE image section/body.bin` using `objdump`. This avoids
requiring local copies of the temporary disassembly files used during the
original analysis.

If an explicitly supplied `.disasm.txt` path does not exist, the tool now
prints a warning and falls back to the UEFI dump instead of aborting.

## Critical KLS71 correction: `+0x896` is not UVP

A second, independent cross-map through Lenovo `SiliconPolicyPeiPreMem` proved
that the earlier Meteor-Lake-derived interpretation was wrong.

On the exact KLS71 Lunar Lake image:

```text
CpuSetup +0x301  DLVR PHASE_SSC
        |
        v
CPU_PM_VR_CONFIG +0x13B
        ^
        |
FSPM +0x896
```

Therefore:

```text
FSPM +0x896 != UnderVoltProtection
PCODE raw 0x48 != proven UVP control
```

The raw `0x48` experiment performed earlier is retained as useful mailbox/timing
data, but it is **not evidence about the UVP control path**.

The validated UVP interface remains the PCODE OC mailbox:

```text
0x37 / subcommand 0x16 = READ_UNDERVOLT_PROTECTION
0x37 / subcommand 0x17 = WRITE_UNDERVOLT_PROTECTION
```

The actual Lunar Lake FSPM UVP field / early lock source is still being reversed.

### Verified KLS71 cross-map

```text
CpuSetup +0x0FA -> CPU_CONFIG_PREMEM bit25    <- FSPM +0x7B5  OC Lock
CpuSetup +0x0FB -> CPU_CONFIG_PREMEM bits9:10 <- FSPM +0x7C1  CPU Run Control
CpuSetup +0x0FC -> CPU_CONFIG_PREMEM bit11    <- FSPM +0x7C2  CPU Run Control Lock

CpuSetup +0x2FE -> CPU_PM_VR_CONFIG +0x0FC <- FSPM +0x882  DLVR RFI Frequency
CpuSetup +0x2FD -> CPU_PM_VR_CONFIG +0x0F7 <- FSPM +0x884  DLVR SSC Value
CpuSetup +0x300 -> CPU_PM_VR_CONFIG +0x0F8 <- FSPM +0x885  Global DLVR RFI mitigation
CpuSetup +0x2F3 -> CPU_PM_VR_CONFIG +0x0F9 <- FSPM +0x886  unknown
CpuSetup +0x2F4 -> CPU_PM_VR_CONFIG +0x0FA <- FSPM +0x887  unknown
CpuSetup +0x2F5 -> CPU_PM_VR_CONFIG +0x0FB <- FSPM +0x888  unknown
CpuSetup +0x301 -> CPU_PM_VR_CONFIG +0x13B <- FSPM +0x896  DLVR PHASE_SSC
CpuSetup +0x304 -> CPU_PM_VR_CONFIG +0x160 <- FSPM +0x897  Vsys/Psys Critical
```

This is why numeric similarity between internal policy offsets and CpuSetup
offsets must never be used as an identification method.
