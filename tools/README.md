# Tools

Only the utilities still useful for the active reverse are kept here.

| Path | Role |
|---|---|
| `analyze-lnl-fspm-uvp/` | read-only mapper for the exact KLS71 `LNLUPD_M`, `FspInitPreMem` and `SiInitPreMemFsp` UVP path |
| `lnl-undervolt/` | guarded Intel MSR `0x150` voltage-offset utility; writes remain blocked while UVP/OC lock are active |
| `lnl-uvp-pcode/` | narrow Linux MCHBAR/PCODE UVP probe used to read the live PCODE state and retest the one-shot disable path while UVP research continues |

The old UEFI timing probes, BDS one-shot driver, raw `0x48` test, battery root-cause tracers and EDP workarounds already produced their useful conclusions and are no longer shipped in the active tree. Those results are preserved in `docs/UNDERVOLT-REVERSE.md` and `docs/BATTERY-EDP-REVERSE.md`.

Generated executables are ignored by Git. Build locally from source.
