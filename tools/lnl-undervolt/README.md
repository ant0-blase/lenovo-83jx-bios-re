# lnl-undervolt

Experimental Intel Lunar Lake OC-mailbox voltage-offset utility for Linux.

This build is intentionally conservative:

- reads MSR 0x10A, 0x194 and IA32_OVERCLOCKING_STATUS (0x195);
- uses OC mailbox MSR 0x150 command 0x10 to read voltage offsets;
- uses command 0x11 to write offsets;
- refuses every write while Undervolt Protection (`0x195 bit 1`) is set;
- refuses every write while the observed OC Lock (`0x194 bit 20`) is set;
- supports undervolting only; on Lunar Lake writes are hard-capped to `-100 .. 0 mV`; no positive offsets;
- reads the offset back after writing and fails if the value did not stick.

## Build

```bash
make
sudo modprobe msr
```

## Current Yoga Slim 7 Lunar Lake state

On the machine reverse-engineered for this build we observed:

```text
MSR 0x194 = 0x10000   (OC Lock cleared)
MSR 0x195 = 0x2       (Undervolt Protection still active)
```

Therefore `set` is expected to refuse until the firmware/FSP policy that enables
UnderVoltProtection is disabled at boot.

## Commands

```bash
sudo ./lnl-undervolt status
sudo ./lnl-undervolt read core
sudo ./lnl-undervolt read ring
sudo ./lnl-undervolt read gt

# Does not touch hardware; prints the exact commands that would be encoded:
./lnl-undervolt encode core -10

# Only works after UVP and OC Lock are both clear:
sudo ./lnl-undervolt set core -10
sudo ./lnl-undervolt set ring -10

sudo ./lnl-undervolt reset core
sudo ./lnl-undervolt reset ring
```

## Plane IDs

The tool uses the conventional Intel FIVR/OC-mailbox plane mapping used by
existing Intel undervolt tools:

- 0 = Core / IA
- 1 = legacy plane 1 (often GT on older CPUs; **not proven on Lunar Lake**)
- 2 = Ring / Cache
- 3 = legacy Uncore
- 4 = legacy Analog I/O
- 5 = legacy Digital I/O

On CPUID family 6 model `0xBD` (Lunar Lake), this build permits **writes only to Core/IA (plane 0) and Ring/Cache (plane 2)**. The Lenovo firmware explicitly documents those two Param1 values for its VF-point mailbox path. Other legacy plane IDs are read-only in this tool until their Lunar Lake semantics are proven. Trust read-back verification rather than the WRMSR return code alone.

## Firmware reverse-engineering note

The Lenovo firmware contains Intel OC/voltage strings documenting MSR 0x150,
cmd 0x10/0x11 and VF-point offsets. The embedded default `LNLUPD_M` blob also
contains a region matching the Meteor Lake Vsys/Psys field sequence; the byte
at `LNLUPD_M + 0x896` is a strong candidate for `UnderVoltProtection`, but it
has not yet been proven sufficiently to patch blindly. The default blob byte
is 0 while the running CPU reports UVP=1, so either the platform overrides the
field before FSP-M consumes it, or the exact Lunar Lake layout/semantics differ.
