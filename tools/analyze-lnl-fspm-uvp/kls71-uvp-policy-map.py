#!/usr/bin/env python3
"""
KLS71 / Lenovo Yoga Slim 7 14ILL10 (83JX)
Lunar Lake FSP-M policy mapper and UVP reverse-engineering guardrail.

READ-ONLY offline tool. It never opens /dev/mem, never writes MSRs, never
modifies NVRAM and never modifies the ROM.

The tool is intentionally anchored to the exact KLS71_sign.rom image used
during the reverse-engineering session unless --allow-unknown-rom is passed.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

KLS71_SHA256 = "21ff6995dc89ee637aceba0f0c37aa9b3b04292d04b8fe7240e512a7874c86bd"
LNLUPD_MAGIC = b"LNLUPD_M"

# Fields currently relevant to the UVP/OC path.
FSPM_FIELDS = {
    # KLS71/Lunar Lake names below are established by cross-matching both
    # FspInitPreMem and Lenovo SiliconPolicyPeiPreMem.  Do NOT reuse the
    # Meteor Lake FSP offsets for this image.
    0x7B5: ("OcLock", 1),
    0x7C1: ("CpuRunControl", 1),
    0x7C2: ("CpuRunControlLock", 1),

    0x882: ("DlvrRfiFrequency", 2),
    0x884: ("DlvrSpreadSpectrumPercentage", 1),
    0x885: ("GlobalDlvrRfiMitigationControl", 1),
    0x886: ("CpuSetup_2F3_unknown", 1),
    0x887: ("CpuSetup_2F4_unknown", 1),
    0x888: ("CpuSetup_2F5_unknown", 1),

    # IMPORTANT CORRECTION:
    # +0x896 is NOT UnderVoltProtection on KLS71.
    0x896: ("DlvrPhaseSsc", 1),
    0x897: ("EnableVsysCritical", 1),
    0x898: ("VsysFullScale", 4),
    0x89C: ("VsysCriticalThreshold", 4),
    0x8A0: ("PsysFullScale", 4),
    0x8A4: ("PsysCriticalThreshold", 4),
    0x8A8: ("VsysAssertionDeglitchMantissa", 1),
    0x8A9: ("VsysAssertionDeglitchExponent", 1),
    0x8AA: ("VsysDeassertionDeglitchMantissa", 1),
    0x8AB: ("VsysDeassertionDeglitchExponent", 1),
}

# Verified Lenovo CpuSetup -> Intel policy -> FSPM cross-map.
# Entries are deliberately limited to mappings proven by the two independent
# initialization paths in the exact KLS71 image.
VERIFIED_CROSSMAP = [
    # cpu_setup, fspm, internal target, name
    (0x0FA, 0x7B5, "CPU_CONFIG_PREMEM +0x1C bit25", "Overclocking Lock"),
    (0x0FB, 0x7C1, "CPU_CONFIG_PREMEM +0x1C bits9:10", "CPU Run Control"),
    (0x0FC, 0x7C2, "CPU_CONFIG_PREMEM +0x1C bit11", "CPU Run Control Lock"),

    (0x2FE, 0x882, "CPU_PM_VR_CONFIG +0xFC", "DLVR RFI Frequency"),
    (0x2FD, 0x884, "CPU_PM_VR_CONFIG +0xF7", "DLVR SSC Value"),
    (0x300, 0x885, "CPU_PM_VR_CONFIG +0xF8", "Global DLVR RFI Mitigation Control"),
    (0x2F3, 0x886, "CPU_PM_VR_CONFIG +0xF9", "unknown CpuSetup 0x2F3"),
    (0x2F4, 0x887, "CPU_PM_VR_CONFIG +0xFA", "unknown CpuSetup 0x2F4"),
    (0x2F5, 0x888, "CPU_PM_VR_CONFIG +0xFB", "unknown CpuSetup 0x2F5"),
    (0x301, 0x896, "CPU_PM_VR_CONFIG +0x13B", "DLVR PHASE_SSC"),
    (0x304, 0x897, "CPU_PM_VR_CONFIG +0x160", "Vsys/Psys Critical"),
    (0x351, 0x898, "CPU_PM_VR_CONFIG +0x178", "Vsys/Psys Full Scale"),
    (0x355, 0x89C, "CPU_PM_VR_CONFIG +0x17C", "Vsys/Psys Critical Threshold"),
    (0x359, 0x8A0, "CPU_PM_VR_CONFIG +0x180", "Vsys/Psys Full Scale"),
    (0x35D, 0x8A4, "CPU_PM_VR_CONFIG +0x184", "Vsys/Psys Critical Threshold"),
    (0x305, 0x8A8, "CPU_PM_VR_CONFIG +0x161", "Assertion Deglitch Mantissa"),
    (0x306, 0x8A9, "CPU_PM_VR_CONFIG +0x162", "Assertion Deglitch Exponent"),
    (0x307, 0x8AA, "CPU_PM_VR_CONFIG +0x163", "Deassertion Deglitch Mantissa"),
    (0x308, 0x8AB, "CPU_PM_VR_CONFIG +0x164", "Deassertion Deglitch Exponent"),
]

# Confirmed from KLS71 FspInitPreMem disassembly.
EXPECTED_POLICY_MAP = {
    0x886: 0x0F9,
    0x887: 0x0FA,
    0x888: 0x0FB,
    0x896: 0x13B,
}

FSP_LOAD_RE = re.compile(
    r"^\s*([0-9a-f]+):.*\bmov\s+al,BYTE PTR \[rdi\+0x([0-9a-f]+)\]",
    re.IGNORECASE,
)
POLICY_STORE_RE = re.compile(
    r"^\s*([0-9a-f]+):.*\bmov\s+BYTE PTR \[rdx\+0x([0-9a-f]+)\],al",
    re.IGNORECASE,
)

CPU_SETUP_INTEREST = {0xFA, 0xFB, 0xFC}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def u16le(data: bytes, off: int) -> int:
    return int.from_bytes(data[off:off + 2], "little")


def u32le(data: bytes, off: int) -> int:
    return int.from_bytes(data[off:off + 4], "little")


def find_all(data: bytes, needle: bytes) -> list[int]:
    out = []
    pos = 0
    while True:
        pos = data.find(needle, pos)
        if pos < 0:
            return out
        out.append(pos)
        pos += 1


def parse_fsp_mapping(text: str) -> list[dict]:
    lines = text.splitlines()
    result = []

    for i, line in enumerate(lines):
        m = FSP_LOAD_RE.search(line)
        if not m:
            continue

        src = int(m.group(2), 16)
        # The matching policy store follows immediately in the KLS71 sequence.
        for j in range(i + 1, min(i + 4, len(lines))):
            s = POLICY_STORE_RE.search(lines[j])
            if s:
                result.append({
                    "fspm_offset": src,
                    "policy_offset": int(s.group(2), 16),
                    "load": line.strip(),
                    "store": lines[j].strip(),
                })
                break

    return result


def contexts(text: str, patterns: list[str], radius: int = 14) -> list[dict]:
    lines = text.splitlines()
    regexes = [re.compile(p, re.IGNORECASE) for p in patterns]
    hits = []

    for i, line in enumerate(lines):
        if not any(r.search(line) for r in regexes):
            continue
        start = max(0, i - radius)
        end = min(len(lines), i + radius + 1)
        hits.append({
            "line": i + 1,
            "match": line.strip(),
            "context": lines[start:end],
        })
    return hits


def parse_cpu_csv(path: Path) -> list[dict]:
    rows = []
    with path.open("r", encoding="utf-8-sig", errors="replace", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            raw = (row.get("offset_hex") or "").strip()
            try:
                off = int(raw, 16)
            except ValueError:
                continue
            if off in CPU_SETUP_INTEREST:
                rows.append({
                    "offset": off,
                    "name": row.get("name", ""),
                    "size_bytes": row.get("size_bytes", ""),
                    "parameters": row.get("parameters", ""),
                    "default": row.get("default", ""),
                    "description_fr": row.get("description_fr", ""),
                    "ifr_help": row.get("ifr_help", ""),
                })
    return rows


def locate_lnlupd_blobs(rom: bytes) -> list[int]:
    """
    KLS71 contains strings/metadata copies of LNLUPD_M in addition to the
    actual FSPM_UPD structures. Keep candidates that are large enough and
    whose known adjacent fields look structurally plausible.

    The two known real KLS71 blobs are additionally reported by exact offset.
    """
    all_hits = find_all(rom, LNLUPD_MAGIC)
    exact_known = {0x00D56764, 0x01156764}
    candidates = []

    for hit in all_hits:
        if hit + 0x8A8 > len(rom):
            continue
        # Structural sanity around the exact UVP neighborhood.
        values = {
            off: rom[hit + off] if size == 1 else
                 u16le(rom, hit + off) if size == 2 else
                 u32le(rom, hit + off)
            for off, (_, size) in FSPM_FIELDS.items()
        }
        score = 0
        if values[0x896] in (0, 1):
            score += 1
        if values[0x897] in (0, 1):
            score += 1
        if values[0x898] < 10_000_000:
            score += 1
        if values[0x89C] < 10_000_000:
            score += 1
        if hit in exact_known:
            score += 10

        candidates.append((score, hit, values))

    candidates.sort(reverse=True)
    return candidates


def fmt_value(value: int, size: int) -> str:
    return f"0x{value:0{size * 2}X} ({value})"


def find_module_te(dump_root: Path, module_name: str) -> Path | None:
    if not dump_root.is_dir():
        return None

    matches = []
    for p in dump_root.rglob("body.bin"):
        s = str(p)
        if module_name in s and "TE image section" in s:
            matches.append(p)

    if not matches:
        return None

    # KLS71 contains duplicated FV copies. Prefer the first lexicographic one;
    # both copies are expected to be byte-identical for the modules we inspect.
    matches.sort(key=lambda p: str(p))
    return matches[0]


def disassemble_kls71_te(te_path: Path, module_name: str) -> str:
    """
    Reconstruct the same raw .text disassembly used during the KLS71 reverse.

    UEFIExtract's KLS71 TE section bodies place the executable .text bytes at
    file offset 0xF0. The first TE section header gives SizeOfRawData. Addresses
    in our previous analysis were ImageBase + file_offset, which is verified
    against the known KLS71 FspInitPreMem/SiInitPreMemFsp images.
    """
    objdump = shutil.which("objdump")
    if objdump is None:
        raise RuntimeError("objdump not found (install binutils)")

    blob = te_path.read_bytes()
    if len(blob) < 0x50 or blob[:2] != b"VZ":
        raise RuntimeError(f"not an EFI TE image: {te_path}")

    machine = int.from_bytes(blob[2:4], "little")
    if machine != 0x8664:
        raise RuntimeError(
            f"unexpected TE machine 0x{machine:04X}; expected x86-64"
        )

    image_base = int.from_bytes(blob[0x10:0x18], "little")

    # EFI_IMAGE_SECTION_HEADER #0 begins immediately after the 0x28-byte
    # EFI_TE_IMAGE_HEADER. We only need the first executable .text section.
    section = 0x28
    section_name = blob[section:section + 8].rstrip(b"\0")
    raw_size = int.from_bytes(blob[section + 16:section + 20], "little")

    if section_name != b".text":
        raise RuntimeError(
            f"first TE section is {section_name!r}, expected b'.text'"
        )

    text_off = 0xF0
    if raw_size <= 0 or text_off + raw_size > len(blob):
        raise RuntimeError(
            f"invalid KLS71 .text range: off=0x{text_off:X} "
            f"size=0x{raw_size:X} file=0x{len(blob):X}"
        )

    text_bytes = blob[text_off:text_off + raw_size]
    vma = image_base + text_off

    with tempfile.NamedTemporaryFile(
        prefix=f"{module_name}-", suffix=".text.bin", delete=True
    ) as tmp:
        tmp.write(text_bytes)
        tmp.flush()

        cp = subprocess.run(
            [
                objdump,
                "-D",
                "-b", "binary",
                "-m", "i386:x86-64",
                "-M", "intel",
                f"--adjust-vma=0x{vma:X}",
                tmp.name,
            ],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

    return cp.stdout


def get_disasm_text(
    explicit_path: Path | None,
    dump_root: Path | None,
    module_name: str,
) -> tuple[str | None, str]:
    if explicit_path is not None and explicit_path.is_file():
        return (
            explicit_path.read_text(encoding="utf-8", errors="replace"),
            str(explicit_path),
        )

    if explicit_path is not None and not explicit_path.exists():
        print(f"WARNING: disassembly not found: {explicit_path}")

    if dump_root is not None:
        te = find_module_te(dump_root, module_name)
        if te is not None:
            print(f"Auto-disassembling {module_name} from:")
            print(f"  {te}")
            return disassemble_kls71_te(te, module_name), f"auto:{te}"

    return None, "not found"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--rom", type=Path, required=True,
                    help="exact KLS71_sign.rom")
    ap.add_argument("--fsp-init-disasm", type=Path,
                    help="FspInitPreMem.disasm.txt")
    ap.add_argument("--si-init-disasm", type=Path,
                    help="SiInitPreMemFsp.disasm.txt")
    ap.add_argument("--cpu-csv", type=Path,
                    help="cpusetup-variables.csv")
    ap.add_argument("--dump-root", type=Path,
                    help="UEFIExtract KLS71_sign.rom.dump directory; "
                         "used to auto-generate missing disassemblies")
    ap.add_argument("--json", type=Path,
                    help="also write machine-readable JSON")
    ap.add_argument("--allow-unknown-rom", action="store_true",
                    help="analyze a non-KLS71 hash; no conclusions are trusted")
    args = ap.parse_args()

    if not args.rom.is_file():
        ap.error(f"ROM not found: {args.rom}")

    digest = sha256(args.rom)
    exact = digest.lower() == KLS71_SHA256

    print("KLS71 / Lunar Lake FSP-M policy cross-map")
    print("==========================================")
    print("READ-ONLY OFFLINE ANALYSIS")
    print()
    print(f"ROM       : {args.rom}")
    print(f"SHA256    : {digest}")
    print(f"Known KLS71: {'YES' if exact else 'NO'}")

    if not exact and not args.allow_unknown_rom:
        print()
        print("REFUSING conclusions: ROM hash does not match the exact KLS71 image.")
        print("Use --allow-unknown-rom only for exploratory read-only output.")
        return 2

    rom = args.rom.read_bytes()

    dump_root = args.dump_root
    if dump_root is None:
        inferred = Path(str(args.rom) + ".dump")
        if inferred.is_dir():
            dump_root = inferred

    if dump_root is not None:
        print(f"UEFI dump : {dump_root}")
    else:
        print("UEFI dump : not supplied / not auto-detected")

    blobs = locate_lnlupd_blobs(rom)

    report = {
        "rom": str(args.rom),
        "sha256": digest,
        "exact_kls71": exact,
        "lnlupd_candidates": [],
        "fsp_policy_map": [],
        "cpu_setup": [],
        "si_contexts": [],
    }

    print()
    print("=== LNLUPD_M candidates ===")
    shown = 0
    for score, hit, values in blobs:
        # Exact KLS71 blobs first; then only reasonably plausible extras.
        if hit not in (0x00D56764, 0x01156764) and score < 4:
            continue
        shown += 1
        print(f"\nLNLUPD_M @ file+0x{hit:08X}  score={score}")
        item = {"offset": hit, "score": score, "fields": {}}

        for off, (name, size) in FSPM_FIELDS.items():
            val = values[off]
            print(f"  +0x{off:03X} {name:34s} = {fmt_value(val, size)}")
            item["fields"][f"0x{off:X}"] = {
                "name": name, "size": size, "value": val
            }

        report["lnlupd_candidates"].append(item)

    if shown == 0:
        print("No structurally plausible LNLUPD_M blob found.")

    fsp_text, fsp_source = get_disasm_text(
        args.fsp_init_disasm, dump_root, "FspInitPreMem"
    )
    if fsp_text is not None:
        print()
        print("=== FspInitPreMem: FSPM_UPD -> internal CPU policy ===")
        print(f"source: {fsp_source}")
        mapping = parse_fsp_mapping(fsp_text)
        interesting = [m for m in mapping if m["fspm_offset"] in
                       set(FSPM_FIELDS) | set(EXPECTED_POLICY_MAP)]

        for m in interesting:
            src = m["fspm_offset"]
            dst = m["policy_offset"]
            expected = EXPECTED_POLICY_MAP.get(src)
            tag = ""
            if expected is not None:
                tag = " [CONFIRMED]" if expected == dst else \
                      f" [MISMATCH expected 0x{expected:X}]"
            print(f"  FSPM +0x{src:03X} -> policy +0x{dst:03X}{tag}")
            report["fsp_policy_map"].append(m)

        print()
        print("Critical KLS71 chain:")
        for src, dst in EXPECTED_POLICY_MAP.items():
            print(f"  +0x{src:03X} -> +0x{dst:03X}")
    else:
        print()
        print("FspInitPreMem disassembly not supplied; mapping check skipped.")

    si_text, si_source = get_disasm_text(
        args.si_init_disasm, dump_root, "SiInitPreMemFsp"
    )
    if si_text is not None:
        print()
        print("=== SiInitPreMemFsp: relevant PCODE policy contexts ===")
        print(f"source: {si_source}")
        hits = contexts(
            si_text,
            patterns=[
                r"\[rbx\+0xf9\]",
                r"\[rbx\+0xfa\]",
                r"\[rbx\+0xfb\]",
                r"\[rax\+0x13b\]",
                r"\[rbx\+0x13b\]",
                r"mov\s+edx,0xa\b",
                r"mov\s+edx,0x48\b",
            ],
            radius=10,
        )

        # Collapse overlapping contexts by line proximity.
        selected = []
        last = -1000
        for h in hits:
            if h["line"] - last < 12:
                continue
            selected.append(h)
            last = h["line"]

        for n, h in enumerate(selected, 1):
            print(f"\n--- context {n} around disasm line {h['line']} ---")
            for line in h["context"]:
                print(line)
            report["si_contexts"].append({
                "line": h["line"],
                "match": h["match"],
            })
    else:
        print()
        print("SiInitPreMemFsp disassembly not supplied; PCODE contexts skipped.")

    if args.cpu_csv and args.cpu_csv.is_file():
        print()
        print("=== CpuSetup fields near the known OC path ===")
        cpu_rows = parse_cpu_csv(args.cpu_csv)
        report["cpu_setup"] = cpu_rows
        for row in cpu_rows:
            print(f"  CpuSetup +0x{row['offset']:03X}: {row['name']}")
            if row["parameters"]:
                print(f"    values : {row['parameters']}")
            if row["ifr_help"]:
                print(f"    IFR    : {row['ifr_help']}")
    else:
        print()
        if args.cpu_csv is not None:
            print(f"WARNING: CpuSetup CSV not found: {args.cpu_csv}")
        print("CpuSetup CSV not supplied/found; IFR cross-reference skipped.")

    print()
    print("=== VERIFIED CpuSetup <-> FSPM cross-map ===")
    for cpu_off, fsp_off, internal, name in VERIFIED_CROSSMAP:
        raw = None
        # Use the first exact real LNLUPD_M blob when present.
        for item in report["lnlupd_candidates"]:
            if item["offset"] in (0x00D56764, 0x01156764):
                key = f"0x{fsp_off:X}"
                if key in item["fields"]:
                    raw = item["fields"][key]["value"]
                    break
        raw_text = "?" if raw is None else f"0x{raw:X}"
        print(
            f"  CpuSetup +0x{cpu_off:03X} -> {internal:<34s} "
            f"<- FSPM +0x{fsp_off:03X}  raw={raw_text:<5s}  {name}"
        )

    print()
    print("=== CRITICAL CORRECTION ===")
    print("KLS71 FSPM +0x896 is DLVR PHASE_SSC, NOT UnderVoltProtection.")
    print("The previous Meteor-Lake-derived +0x896 UVP label is invalid.")
    print("Therefore raw PCODE command 0x48 gated by policy +0x13B is part")
    print("of the DLVR/PHASE_SSC path and must not be treated as the UVP command.")
    print("The verified UVP mailbox interface remains PCODE OC 0x37,")
    print("subcommand 0x16=READ_UVP and 0x17=WRITE_UVP.")
    print("The actual Lunar Lake FSPM UVP field/lock source is still unresolved.")

    print()
    print("=== Interpretation guardrails ===")
    print("1. Do NOT patch FSPM +0x896 for UVP: it is DLVR PHASE_SSC.")
    print("2. Do NOT use raw PCODE 0x48 as a UVP disable command on this image.")
    print("3. FSPM +0x886/+0x887/+0x888 map to the DLVR/VR policy region")
    print("   +0xF9/+0xFA/+0xFB and come from CpuSetup +0x2F3/+0x2F4/+0x2F5.")
    print("4. CpuSetup +0xFA/+0xFB/+0xFC are a separate CPU_CONFIG_PREMEM")
    print("   path: OC Lock / CPU Run Control / CPU Run Control Lock.")
    print("5. MSR 0x195 bit1=1 plus PCODE OC 0x37/0x17 -> PCODE_LOCKED")
    print("   remains the valid live evidence that runtime UVP is active/locked.")
    print("6. The actual Lunar Lake UVP policy source must be identified before")
    print("   producing any flashable firmware modification.")
    print("7. This tool intentionally does not generate a flashable ROM.")

    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(
            json.dumps(report, indent=2),
            encoding="utf-8"
        )
        print()
        print(f"JSON written: {args.json}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
