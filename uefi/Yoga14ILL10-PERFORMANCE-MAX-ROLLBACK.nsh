@echo -off

echo ============================================================
echo Lenovo Yoga Slim 7 14ILL10 (83JX) - PERFORMANCE MAX ROLLBACK
echo ============================================================
echo.
echo Restores the KLS71 reference/OEM values for every persistent CpuSetup
echo / SaSetup field written by Yoga14ILL10-PERFORMANCE-MAX.nsh.
echo.
echo This is a STOCK-REFERENCE rollback, not a snapshot of custom values that
echo may have existed before PERFORMANCE MAX was applied.
echo Intel IPF / DptfConfig was not modified by PERFORMANCE MAX and is untouched.
echo Thermal Monitor, TCC, VR thermal alert, ICCMAX, TDC, Fast Vmode and EC/BMS
echo protections remain untouched.
echo.

echo ===== CPU HWP / IDLE / BOOST REFERENCE VALUES =====
setup_var.efi CpuSetup:0x8(1)=1
echo EIST = Enabled
setup_var.efi CpuSetup:0x9(1)=1
echo Race To Halt = Enabled
setup_var.efi CpuSetup:0xA(1)=1
echo Speed Shift / HWP = Enabled
setup_var.efi CpuSetup:0xB(1)=1
echo Boot Max Frequency = Enabled
setup_var.efi CpuSetup:0xF(1)=2
echo Boot Performance Mode = Turbo Performance reference value
setup_var.efi CpuSetup:0xD(1)=1
setup_var.efi CpuSetup:0xE(1)=1
echo HWP autonomous controls = Enabled
setup_var.efi CpuSetup:0x237(1)=1
echo HWP Lock = Enabled/default
setup_var.efi CpuSetup:0x21C(1)=1
echo Speed Shift interrupt control = Enabled
setup_var.efi CpuSetup:0x12(1)=1
echo Turbo = Enabled
setup_var.efi CpuSetup:0x10(1)=1
setup_var.efi CpuSetup:0x11(1)=1
echo C-states / C1E = Enabled
setup_var.efi CpuSetup:0x4B(1)=255
echo Package C-state = Auto
setup_var.efi CpuSetup:0x3C(1)=1
setup_var.efi CpuSetup:0x1EB(1)=1
echo Energy Efficient P-state / Turbo = Enabled
setup_var.efi CpuSetup:0x33A(1)=0
echo DFD debug fabric = Disabled
setup_var.efi CpuSetup:0x3DA(1)=1
echo Power Floor Management = Enabled/default

echo.
echo ===== POWER LIMITS / TRANSIENT POLICY =====
echo Remove custom Package PL1 programming.
setup_var.efi CpuSetup:0x17(1)=0
setup_var.efi CpuSetup:0x13(4)=0
setup_var.efi CpuSetup:0x30(1)=0

echo Restore Platform PL1/PL2 to firmware-default programming.
setup_var.efi CpuSetup:0x31(1)=0
setup_var.efi CpuSetup:0x32(4)=0
setup_var.efi CpuSetup:0x36(1)=0
setup_var.efi CpuSetup:0x37(1)=0
setup_var.efi CpuSetup:0x38(4)=0

echo Restore raw PL4 policy and remove Reactive PL4 Boost.
setup_var.efi CpuSetup:0x26(1)=1
setup_var.efi CpuSetup:0x2B(1)=0
setup_var.efi CpuSetup:0x2C(4)=0

echo ThETA Ibatt = Disabled/default.
setup_var.efi CpuSetup:0x1E0(1)=0

echo Restore hardware/default demotion algorithms.
setup_var.efi CpuSetup:0x3D8(1)=1
setup_var.efi CpuSetup:0x3D9(1)=1

echo.
echo ===== CLOCK / VR TRANSITION REFERENCE VALUES =====
setup_var.efi CpuSetup:0x232(1)=1
echo BCLK Spread Spectrum = Enabled/default
setup_var.efi CpuSetup:0x20F(1)=0
echo Acoustic Noise Mitigation = Disabled/default
setup_var.efi CpuSetup:0x216(1)=0
setup_var.efi CpuSetup:0x217(1)=0
setup_var.efi CpuSetup:0x219(1)=0
echo Core / GT / ATOM slow-slew = reference values
setup_var.efi CpuSetup:0x236(1)=1
echo Configurable Base Power / cTDP init = normal/default

echo.
echo ===== P-CORE / GT LOAD-LINE ROLLBACK =====
setup_var.efi CpuSetup:0x10D(1)=1
setup_var.efi CpuSetup:0x113(2)=0
echo P-core VR block enabled, AC Loadline = AUTO/HW default
setup_var.efi CpuSetup:0x10E(1)=1
setup_var.efi CpuSetup:0x115(2)=0
echo GT VR block enabled, AC Loadline = AUTO/HW default

echo.
echo ===== MEMORY / SYSTEM AGENT / iGPU REFERENCE VALUES =====
setup_var.efi SaSetup:0x9D(2)=0
echo Maximum Memory Frequency = AUTO
setup_var.efi SaSetup:0x160(1)=1
setup_var.efi SaSetup:0x161(1)=15
echo SAGV = Enabled, all four points
setup_var.efi SaSetup:0x162(2)=0
setup_var.efi SaSetup:0x164(2)=0
setup_var.efi SaSetup:0x166(2)=0
setup_var.efi SaSetup:0x168(2)=0
setup_var.efi SaSetup:0x16A(1)=0
setup_var.efi SaSetup:0x16B(1)=0
setup_var.efi SaSetup:0x16C(1)=0
setup_var.efi SaSetup:0x16D(1)=0
echo Individual SAGV frequencies/gears = MRC Auto
setup_var.efi SaSetup:0xC4(1)=255
setup_var.efi SaSetup:0xC5(1)=0
echo Memory Power Down = Auto/reference
setup_var.efi SaSetup:0xC6(1)=0
setup_var.efi SaSetup:0x112(1)=0
setup_var.efi SaSetup:0x1CC(1)=1
setup_var.efi SaSetup:0x214(1)=0
setup_var.efi SaSetup:0x32(1)=1
setup_var.efi SaSetup:0x2E(1)=1
setup_var.efi SaSetup:0x2F(1)=1
setup_var.efi SaSetup:0x39(1)=1
echo Page-close / Cycle Bypass / Scrambler / GT / RC6 / MC6 / MBC = reference

echo.
echo ===== RESTORE BD PROCHOT RUNTIME INPUT =====
echo Setting MSR_POWER_CTL 0x1FC bit 0 only; all other bits are preserved.
BDPROCHOT-RESTORE.efi

echo.
echo ===== VERIFY KEY ROLLBACK VALUES =====
echo HWP Lock / Package PL1 override / Platform PL1 / Platform PL2:
setup_var.efi CpuSetup:0x237(1)
setup_var.efi CpuSetup:0x17(1)
setup_var.efi CpuSetup:0x31(1)
setup_var.efi CpuSetup:0x32(4)
setup_var.efi CpuSetup:0x37(1)
setup_var.efi CpuSetup:0x38(4)
echo PL4 Override / Boost / demotions / BCLK:
setup_var.efi CpuSetup:0x26(1)
setup_var.efi CpuSetup:0x2C(4)
setup_var.efi CpuSetup:0x3D8(1)
setup_var.efi CpuSetup:0x3D9(1)
setup_var.efi CpuSetup:0x232(1)
echo P-core / GT AC Loadline:
setup_var.efi CpuSetup:0x113(2)
setup_var.efi CpuSetup:0x115(2)
echo Memory Max / SAGV / RC6 / MC6 / MBC:
setup_var.efi SaSetup:0x9D(2)
setup_var.efi SaSetup:0x160(1)
setup_var.efi SaSetup:0x161(1)
setup_var.efi SaSetup:0x2E(1)
setup_var.efi SaSetup:0x2F(1)
setup_var.efi SaSetup:0x39(1)
echo.
echo Expected key values:
echo HWPLock=01 PackagePL1Override=00 PlatformPL1/2=disabled values=0
echo PL4Override=01 ReactivePL4=0 ProchotDemotion=01 VrAlertDemotion=01 BCLKSpread=01
echo PcoreACLL=0000 GTACLL=0000 MemMax=0000 SAGV=01 mask=0F RC6/MC6/MBC=01/01/01
echo.
echo IMPORTANT: fully shut down and cold boot after this rollback.
echo If you want the broadest possible firmware reset, BIOS Load Setup Defaults remains
echo the authoritative OEM reset and can be used after this script as well.
pause
