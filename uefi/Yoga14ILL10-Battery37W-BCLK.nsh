@echo -off
echo Lenovo Yoga Slim 7 14ILL10 83JX - Battery 37W + BCLK - MAX PL4 experiment
echo
echo Consolidated max-performance profile.
echo It combines BCLK Spread OFF, explicit 37W power paths and MAX Reactive PL4 Boost.
echo 7.5W PL4 Boost was causally validated against the persistent EDP clamp.
echo 63W is the IFR maximum and is an aggressive headroom experiment, not a proven optimum.
echo
echo WARNING: maximum PL4 Boost can increase transient battery droop/current and VR stress.
echo It does NOT disable PROCHOT, Thermal Monitor, VR thermal alert, ICCMAX,
echo TDC, load-line, voltage or raw EC/BMS protection.
echo
echo ===== Current BCLK =====
setup_var.efi CpuSetup:0x232(1)
echo
echo ===== Current battery-policy companions =====
setup_var.efi CpuSetup:0x1E0(1)
setup_var.efi CpuSetup:0x3D9(1)
echo
echo ===== Current Package PL1 =====
setup_var.efi CpuSetup:0x13(4)
setup_var.efi CpuSetup:0x17(1)
echo
echo ===== Current Platform 37W path =====
setup_var.efi CpuSetup:0x30(1)
setup_var.efi CpuSetup:0x31(1)
setup_var.efi CpuSetup:0x32(4)
setup_var.efi CpuSetup:0x36(1)
setup_var.efi CpuSetup:0x37(1)
setup_var.efi CpuSetup:0x38(4)
echo
echo ===== Current PL4 Boost =====
setup_var.efi CpuSetup:0x2C(4)
echo
echo ===== Clean cTDP / PSYS state =====
setup_var.efi CpuSetup:0x10B(2)
setup_var.efi CpuSetup:0x45(1)
setup_var.efi CpuSetup:0x236(1)
echo
echo ===== Apply final working profile =====
echo Restore normal PSYS / cTDP state from the failed experiments.
setup_var.efi CpuSetup:0x10B(2)=0
setup_var.efi CpuSetup:0x45(1)=0
setup_var.efi CpuSetup:0x236(1)=1

echo Keep battery-current policy disabled and VrAlert demotion companion tweak.
setup_var.efi CpuSetup:0x1E0(1)=0
setup_var.efi CpuSetup:0x3D9(1)=0

echo Disable BCLK Spread Spectrum.
setup_var.efi CpuSetup:0x232(1)=0

echo Keep PACKAGE_POWER_LIMIT programming unlocked.
setup_var.efi CpuSetup:0x30(1)=0

echo Explicit CPU Package PL1 = 37000 mW.
setup_var.efi CpuSetup:0x13(4)=37000
setup_var.efi CpuSetup:0x17(1)=1

echo Explicit Platform PL1 = 37000 mW, default time window.
setup_var.efi CpuSetup:0x31(1)=1
setup_var.efi CpuSetup:0x32(4)=37000
setup_var.efi CpuSetup:0x36(1)=0

echo Explicit Platform PL2 = 37000 mW.
setup_var.efi CpuSetup:0x37(1)=1
setup_var.efi CpuSetup:0x38(4)=37000

echo Reactive PL4 Boost = 63000 mW - IFR MAX.
echo Maximum exposed Reactive PL4 Boost for this firmware.
echo PL1/PL2 remain 37000 mW and all thermal/VR/EC/BMS protections stay enabled.
setup_var.efi CpuSetup:0x2C(4)=63000

echo
echo ===== Verify =====
echo BCLK Spread:
setup_var.efi CpuSetup:0x232(1)
echo Battery companions:
setup_var.efi CpuSetup:0x1E0(1)
setup_var.efi CpuSetup:0x3D9(1)
echo Package PL1:
setup_var.efi CpuSetup:0x13(4)
setup_var.efi CpuSetup:0x17(1)
echo Platform power:
setup_var.efi CpuSetup:0x30(1)
setup_var.efi CpuSetup:0x31(1)
setup_var.efi CpuSetup:0x32(4)
setup_var.efi CpuSetup:0x36(1)
setup_var.efi CpuSetup:0x37(1)
setup_var.efi CpuSetup:0x38(4)
echo Reactive PL4 Boost:
setup_var.efi CpuSetup:0x2C(4)
echo PSYS / cTDP baseline:
setup_var.efi CpuSetup:0x10B(2)
setup_var.efi CpuSetup:0x45(1)
setup_var.efi CpuSetup:0x236(1)
echo
echo Expected key values:
echo BCLK 00
echo battery 00 00
echo Package PL1 00009088 / 01
echo Platform 00 01 00009088 00 01 00009088
echo PL4 Boost 0000F618
echo baseline 0000 00 01
echo
echo Cold reboot required.
pause
