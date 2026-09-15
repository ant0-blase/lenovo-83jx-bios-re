@echo -off

echo ============================================================
echo Lenovo Yoga Slim 7 14ILL10 (83JX) - PERFORMANCE MAX CPU + iGPU
echo ============================================================
echo.
echo Target: maximum practical CPU + iGPU performance with efficient idle/battery behavior.
echo This profile uses only offsets recovered for this exact 83JX firmware.
echo.
echo IMPORTANT DESIGN CHOICES:
echo - C-states/C1E remain ENABLED: forcing them off previously hurt Turbo.
echo - Package C-state limit remains AUTO for best observed practical boost.
echo - PL1/PL2 are explicitly aligned to the known 37 W platform target.
echo - EIST + Speed Shift + per-core HWP autonomy stay ENABLED for fast ramping.
echo - Boot Max Frequency + Turbo Performance are explicitly selected.
echo - HWP Lock is disabled so Windows can update HWP policy at runtime.
echo - Race-To-Halt stays ENABLED to finish bursts fast and return to C-states.
echo - Battery efficiency is preserved with HWP/EIST, C-states, SAGV, RC6/MC6 and memory power-down.
echo - Energy Efficient Turbo stays ENABLED to preserve CPU+iGPU package perf/W.
echo - LPDDR5X maximum-frequency ceiling is set to 8533 while SAGV remains enabled.
echo - Intel IPF/DTT firmware variables are left untouched; Windows policy is tuned separately.
echo - Reactive PL4 Boost is set to the IFR maximum 63 W.
echo - P-core AC load-line is set to experimental 2.50 mOhm.
echo - GT/iGPU AC load-line is set to experimental 2.50 mOhm.
echo - Thermal Monitor, TCC, VR thermal alert, ICCMAX, TDC, Fast Vmode,
echo   ISYS current limits and EC/BMS protections are NOT disabled.
echo - BD PROCHOT external input is disabled by BDPROCHOT.efi when present.
echo.

echo ===== BEFORE =====
echo CPU Turbo / C-states / C1E / Package C-state:
setup_var.efi CpuSetup:0x12(1)
setup_var.efi CpuSetup:0x10(1)
setup_var.efi CpuSetup:0x11(1)
setup_var.efi CpuSetup:0x4B(1)
echo EIST / RTH / Speed Shift / HWP autonomy / EEP / EET:
setup_var.efi CpuSetup:0x8(1)
setup_var.efi CpuSetup:0x9(1)
setup_var.efi CpuSetup:0xA(1)
setup_var.efi CpuSetup:0xB(1)
setup_var.efi CpuSetup:0xF(1)
setup_var.efi CpuSetup:0xD(1)
setup_var.efi CpuSetup:0xE(1)
setup_var.efi CpuSetup:0x237(1)
setup_var.efi CpuSetup:0x21C(1)
setup_var.efi CpuSetup:0x3C(1)
setup_var.efi CpuSetup:0x1EB(1)
echo DFD debug fabric:
setup_var.efi CpuSetup:0x33A(1)
setup_var.efi CpuSetup:0x3DA(1)
echo Package PL1 / Platform PL1 / Platform PL2:
setup_var.efi CpuSetup:0x13(4)
setup_var.efi CpuSetup:0x17(1)
setup_var.efi CpuSetup:0x31(1)
setup_var.efi CpuSetup:0x32(4)
setup_var.efi CpuSetup:0x37(1)
setup_var.efi CpuSetup:0x38(4)
echo Reactive PL4 / ThETA / PROCHOT demotion / VrAlert demotion:
setup_var.efi CpuSetup:0x2C(4)
setup_var.efi CpuSetup:0x1E0(1)
setup_var.efi CpuSetup:0x3D8(1)
setup_var.efi CpuSetup:0x3D9(1)
echo BCLK / slew / acoustic:
setup_var.efi CpuSetup:0x232(1)
setup_var.efi CpuSetup:0x20F(1)
setup_var.efi CpuSetup:0x216(1)
setup_var.efi CpuSetup:0x217(1)
setup_var.efi CpuSetup:0x219(1)
echo P-core VR enable / AC LL / DC LL / ICCMAX / TDC / Fast Vmode:
setup_var.efi CpuSetup:0x10D(1)
setup_var.efi CpuSetup:0x113(2)
setup_var.efi CpuSetup:0x11F(2)
setup_var.efi CpuSetup:0x185(2)
setup_var.efi CpuSetup:0x191(2)
setup_var.efi CpuSetup:0x19D(1)
setup_var.efi CpuSetup:0x348(1)
echo GT/iGPU VR enable / AC LL / DC LL / ICCMAX / TDC / Fast Vmode:
setup_var.efi CpuSetup:0x10E(1)
setup_var.efi CpuSetup:0x115(2)
setup_var.efi CpuSetup:0x121(2)
setup_var.efi CpuSetup:0x187(2)
setup_var.efi CpuSetup:0x193(2)
setup_var.efi CpuSetup:0x19E(1)
setup_var.efi CpuSetup:0x349(1)
echo.

echo ===== CPU BOOST / HWP / IDLE POLICY =====
echo Intel SpeedStep EIST = Enabled
setup_var.efi CpuSetup:0x8(1)=1

echo Race To Halt = Enabled
echo Finish short CPU bursts quickly, then let cores return to low-power states.
setup_var.efi CpuSetup:0x9(1)=1

echo Intel Speed Shift / HWP CPPC v2 = Enabled
setup_var.efi CpuSetup:0xA(1)=1

echo Boot Max Frequency = Enabled
setup_var.efi CpuSetup:0xB(1)=1

echo Boot Performance Mode = Turbo Performance
setup_var.efi CpuSetup:0xF(1)=2

echo HWP Autonomous Per-Core P-state = Enabled
setup_var.efi CpuSetup:0xD(1)=1

echo HWP Autonomous EPP Grouping = Enabled
setup_var.efi CpuSetup:0xE(1)=1

echo HWP Lock = Disabled
echo Keep OS/ThrottleStop/Windows power-plan HWP policy writable at runtime.
setup_var.efi CpuSetup:0x237(1)=0

echo Speed Shift interrupt control = Enabled
setup_var.efi CpuSetup:0x21C(1)=1

echo Turbo Mode = Enabled
setup_var.efi CpuSetup:0x12(1)=1

echo CPU C-states = Enabled - better Turbo observed than forced OFF
setup_var.efi CpuSetup:0x10(1)=1

echo C1E = Enabled - keep normal boost-friendly idle transitions
setup_var.efi CpuSetup:0x11(1)=1

echo Package C-State Limit = Auto
setup_var.efi CpuSetup:0x4B(1)=255

echo Energy Efficient P-state interface = Enabled
echo Keep Windows HWP / Ultimate Performance policy functional.
setup_var.efi CpuSetup:0x3C(1)=1

echo Energy Efficient Turbo = Enabled
echo On a shared CPU+iGPU package budget this avoids wasting watts on opportunistic
echo CPU turbo that can otherwise steal thermal/power headroom from the Arc iGPU.
setup_var.efi CpuSetup:0x1EB(1)=1

echo DFD debug fabric = Disabled
setup_var.efi CpuSetup:0x33A(1)=0

echo Power Floor Management = Enabled
echo Keep efficient SoC floor-power control active; disabling can raise idle/floor power.
setup_var.efi CpuSetup:0x3DA(1)=1

echo ===== INTEL IPF / DYNAMIC TUNING =====
echo No DptfConfig/IPF variable is changed by this profile.
echo The Windows-only 8 W issue was resolved through the Windows power policy,
echo so OEM thermal/power plumbing remains available for normal platform behavior.
echo.

echo ===== 37 W SUSTAINED PACKAGE / PLATFORM PATH =====
echo Package PL1 = 37000 mW, override enabled
setup_var.efi CpuSetup:0x13(4)=37000
setup_var.efi CpuSetup:0x17(1)=1

echo Package power-limit MSR lock = Disabled
setup_var.efi CpuSetup:0x30(1)=0

echo Platform PL1 = 37000 mW
setup_var.efi CpuSetup:0x31(1)=1
setup_var.efi CpuSetup:0x32(4)=37000
setup_var.efi CpuSetup:0x36(1)=0

echo Platform PL2 = 37000 mW
setup_var.efi CpuSetup:0x37(1)=1
setup_var.efi CpuSetup:0x38(4)=37000

echo ===== TRANSIENT / DEMOTION HEADROOM =====
echo Raw PL4 override = Disabled; PL4 lock = Disabled
setup_var.efi CpuSetup:0x26(1)=0
setup_var.efi CpuSetup:0x2B(1)=0

echo Reactive Power Limit 4 Boost = 63000 mW - IFR maximum
setup_var.efi CpuSetup:0x2C(4)=63000

echo ThETA Ibatt = Disabled
setup_var.efi CpuSetup:0x1E0(1)=0

echo PROCHOT Demotion algorithm = Disabled
echo Internal Thermal Monitor / TCC remain enabled.
setup_var.efi CpuSetup:0x3D8(1)=0

echo VrAlert Demotion algorithm = Disabled
echo VR thermal alert itself remains enabled.
setup_var.efi CpuSetup:0x3D9(1)=0

echo ===== CLOCK / VR TRANSITION POLICY =====
echo BCLK Spread Spectrum = Disabled
setup_var.efi CpuSetup:0x232(1)=0

echo Acoustic Noise Mitigation = Disabled
setup_var.efi CpuSetup:0x20F(1)=0

echo Core / GT / ATOM slow-slew selectors = fastest exposed value
setup_var.efi CpuSetup:0x216(1)=0
setup_var.efi CpuSetup:0x217(1)=0
setup_var.efi CpuSetup:0x219(1)=0

echo Keep normal Configurable Base Power path - bypass previously caused low-power fallback
setup_var.efi CpuSetup:0x236(1)=1

echo ===== P-CORE PERFORMANCE / LOAD-LINE TUNE =====
echo P-core VR custom configuration = Enabled
setup_var.efi CpuSetup:0x10D(1)=1

echo P-core AC Loadline = 250 raw = 2.50 mOhm
echo Stock runtime observation was about 4.00 mOhm; 2.50 is experimental.
echo This is a VR/load-line undervolt, not an MSR 0x150 voltage-offset undervolt.
echo If CPU instability appears, restore CpuSetup:0x113(2)=0 for AUTO.
setup_var.efi CpuSetup:0x113(2)=250

echo P-core DC Loadline / ICCMAX / TDC / Fast Vmode intentionally untouched.
echo MSR 0x150 offset undervolt is NOT written because UVP remains active.
echo.

echo ===== MEMORY / SYSTEM AGENT PERFORMANCE-WATT TUNE =====
echo QCLK Odd Ratio = Enabled
echo Use the tested KLS71 MRC path: Custom profile, 133 MHz RefClk, memory ratio AUTO.
echo Manual DRAM timing fields are left untouched by this profile.
setup_var.efi SaSetup:0x9F(1)=1
setup_var.efi SaSetup:0x09(1)=0
setup_var.efi SaSetup:0x0A(1)=0
setup_var.efi SaSetup:0x0B(1)=1
echo QCLK / MRC profile readback:
setup_var.efi SaSetup:0x9F(1)
setup_var.efi SaSetup:0x09(1)
setup_var.efi SaSetup:0x0A(1)
setup_var.efi SaSetup:0x0B(1)
echo.
echo Maximum Memory Frequency ceiling = 8533 MT/s
echo SAGV remains enabled, so this is the top point/ceiling rather than a fixed idle clock.
setup_var.efi SaSetup:0x9D(2)=8533

echo Keep SAGV enabled with all four switching points.
setup_var.efi SaSetup:0x160(1)=1
setup_var.efi SaSetup:0x161(1)=15

echo Leave individual SAGV point frequencies and gear ratios on MRC Auto.
setup_var.efi SaSetup:0x162(2)=0
setup_var.efi SaSetup:0x164(2)=0
setup_var.efi SaSetup:0x166(2)=0
setup_var.efi SaSetup:0x168(2)=0
setup_var.efi SaSetup:0x16A(1)=0
setup_var.efi SaSetup:0x16B(1)=0
setup_var.efi SaSetup:0x16C(1)=0
setup_var.efi SaSetup:0x16D(1)=0

echo Keep memory power-down AUTO for battery/temperature efficiency.
setup_var.efi SaSetup:0xC4(1)=255
setup_var.efi SaSetup:0xC5(1)=0

echo Page Close Idle Timeout = Enabled - KLS71 uses inverted encoding here.
setup_var.efi SaSetup:0xC6(1)=0

echo Cycle Bypass Support = Enabled - KLS71 uses inverted encoding here.
setup_var.efi SaSetup:0x112(1)=0

echo Memory Scrambler = Enabled
setup_var.efi SaSetup:0x1CC(1)=1

echo Probeless Trace Support = Disabled
setup_var.efi SaSetup:0x214(1)=0

echo NPU Device = Disabled
echo Remove the Lunar Lake NPU from the OS-visible platform.
setup_var.efi SaSetup:0x204(1)=0

echo ===== GT / iGPU PERFORMANCE-WATT TUNE =====
echo Configure GT in BIOS = Enabled
setup_var.efi SaSetup:0x32(1)=1

echo Keep RC6 + MC6 + memory bandwidth compression enabled for best iGPU/media perf/W.
setup_var.efi SaSetup:0x2E(1)=1
setup_var.efi SaSetup:0x2F(1)=1
setup_var.efi SaSetup:0x39(1)=1

echo GT VR custom configuration = Enabled
setup_var.efi CpuSetup:0x10E(1)=1

echo GT AC Loadline = 250 raw = 2.50 mOhm
echo Stock runtime observation was about 3.00 mOhm; 2.50 is experimental.
echo If GPU instability appears, restore CpuSetup:0x115(2)=0 for AUTO.
setup_var.efi CpuSetup:0x115(2)=250

echo GT DC Loadline / ICCMAX / TDC / Fast Vmode intentionally untouched.
echo Their recovered fields remain available for audit only below.
echo.

echo ===== BD PROCHOT EXTERNAL INPUT =====
echo Clearing MSR_POWER_CTL 0x1FC bit 0 only.
BDPROCHOT.efi

echo.
echo ===== VERIFY =====
echo EIST / RTH / HWP / autonomous policy / Turbo / C-states / EEP / EET:
setup_var.efi CpuSetup:0x8(1)
setup_var.efi CpuSetup:0x9(1)
setup_var.efi CpuSetup:0xA(1)
setup_var.efi CpuSetup:0xB(1)
setup_var.efi CpuSetup:0xF(1)
setup_var.efi CpuSetup:0xD(1)
setup_var.efi CpuSetup:0xE(1)
setup_var.efi CpuSetup:0x237(1)
setup_var.efi CpuSetup:0x21C(1)
setup_var.efi CpuSetup:0x12(1)
setup_var.efi CpuSetup:0x10(1)
setup_var.efi CpuSetup:0x11(1)
setup_var.efi CpuSetup:0x4B(1)
setup_var.efi CpuSetup:0x3C(1)
setup_var.efi CpuSetup:0x1EB(1)
setup_var.efi CpuSetup:0x33A(1)
setup_var.efi CpuSetup:0x3DA(1)
echo Memory / SA / GT efficiency:
setup_var.efi SaSetup:0x9D(2)
setup_var.efi SaSetup:0x160(1)
setup_var.efi SaSetup:0x161(1)
setup_var.efi SaSetup:0xC4(1)
setup_var.efi SaSetup:0xC5(1)
setup_var.efi SaSetup:0xC6(1)
setup_var.efi SaSetup:0x112(1)
setup_var.efi SaSetup:0x1CC(1)
setup_var.efi SaSetup:0x214(1)
setup_var.efi SaSetup:0x204(1)
setup_var.efi SaSetup:0x32(1)
setup_var.efi SaSetup:0x2E(1)
setup_var.efi SaSetup:0x2F(1)
setup_var.efi SaSetup:0x39(1)
echo 37 W path:
setup_var.efi CpuSetup:0x13(4)
setup_var.efi CpuSetup:0x17(1)
setup_var.efi CpuSetup:0x30(1)
setup_var.efi CpuSetup:0x31(1)
setup_var.efi CpuSetup:0x32(4)
setup_var.efi CpuSetup:0x36(1)
setup_var.efi CpuSetup:0x37(1)
setup_var.efi CpuSetup:0x38(4)
echo Reactive PL4 / demotions:
setup_var.efi CpuSetup:0x2C(4)
setup_var.efi CpuSetup:0x1E0(1)
setup_var.efi CpuSetup:0x3D8(1)
setup_var.efi CpuSetup:0x3D9(1)
echo Clock / slew:
setup_var.efi CpuSetup:0x232(1)
setup_var.efi CpuSetup:0x20F(1)
setup_var.efi CpuSetup:0x216(1)
setup_var.efi CpuSetup:0x217(1)
setup_var.efi CpuSetup:0x219(1)
echo P-core tune and protected limits:
setup_var.efi CpuSetup:0x10D(1)
setup_var.efi CpuSetup:0x113(2)
setup_var.efi CpuSetup:0x11F(2)
setup_var.efi CpuSetup:0x185(2)
setup_var.efi CpuSetup:0x191(2)
setup_var.efi CpuSetup:0x19D(1)
setup_var.efi CpuSetup:0x348(1)
echo GT tune and protected limits:
setup_var.efi CpuSetup:0x10E(1)
setup_var.efi CpuSetup:0x115(2)
setup_var.efi CpuSetup:0x121(2)
setup_var.efi CpuSetup:0x187(2)
setup_var.efi CpuSetup:0x193(2)
setup_var.efi CpuSetup:0x19E(1)
setup_var.efi CpuSetup:0x349(1)
echo.
echo Expected tuned values:
echo EIST/RTH/HWP/BootMax/BootMode/Autonomous/EPPgroup/HWPLock/SSint=01/01/01/01/02/01/01/00/01
echo Turbo=01 Cstates=01 C1E=01 PackageCState=FF EEPstate=01 EET=01 DFD=00 PowerFloor=01
echo MemMax=2155h(8533) SAGV=01 mask=0F PowerDown=FF PageClose=00 CycleBypass=00
echo Scrambler=01 Trace=00 GTconfig=01 RC6=01 MC6=01 MBC=01
echo PL1=00009088 override=01 PlatformPL1/2=00009088 enabled
echo ReactivePL4=0000F618 ThETA=00 ProchotDemotion=00 VrAlertDemotion=00
echo BCLKSpread=00 Acoustic=00 SlewCore/GT/ATOM=00/00/00
echo P-core VR=01 P-core AC_LL=000000FA
echo GT VR=01 GT AC_LL=000000FA
echo.
echo Full shutdown / cold boot required for persistent CpuSetup fields.
echo After cold boot, run this script once more before Windows if you want
echo BDPROCHOT.efi applied for that boot.
echo Use windows\Yoga14ILL10-PERFORMANCE-MAX.ps1 after selecting Ultimate Performance.
echo AC keeps the known-good maximum-performance policy; DC uses efficient HWP settings.
pause
