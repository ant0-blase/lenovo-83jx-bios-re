@echo -off
echo Lenovo Yoga Slim 7 14ILL10 83JX - rollback Battery 37W + BCLK profile
echo
echo Restores the reference/default values owned by Yoga14ILL10-Battery37W-BCLK.nsh.
echo Performance baseline settings are left alone.
echo
echo ===== Restore =====
echo BCLK Spread Spectrum = Enabled/default
setup_var.efi CpuSetup:0x232(1)=1

echo Battery policy reference defaults
setup_var.efi CpuSetup:0x1E0(1)=0
setup_var.efi CpuSetup:0x3D9(1)=1

echo CPU Package PL1 custom override = off / auto
setup_var.efi CpuSetup:0x13(4)=0
setup_var.efi CpuSetup:0x17(1)=0

echo Platform power limits = firmware defaults
setup_var.efi CpuSetup:0x30(1)=0
setup_var.efi CpuSetup:0x31(1)=0
setup_var.efi CpuSetup:0x32(4)=0
setup_var.efi CpuSetup:0x36(1)=0
setup_var.efi CpuSetup:0x37(1)=0
setup_var.efi CpuSetup:0x38(4)=0

echo Reactive PL4 Boost = disabled/default
setup_var.efi CpuSetup:0x2C(4)=0

echo Clean PSYS / cTDP baseline
setup_var.efi CpuSetup:0x10B(2)=0
setup_var.efi CpuSetup:0x45(1)=0
setup_var.efi CpuSetup:0x236(1)=1

echo
echo ===== Verify =====
setup_var.efi CpuSetup:0x232(1)
setup_var.efi CpuSetup:0x1E0(1)
setup_var.efi CpuSetup:0x3D9(1)
setup_var.efi CpuSetup:0x13(4)
setup_var.efi CpuSetup:0x17(1)
setup_var.efi CpuSetup:0x30(1)
setup_var.efi CpuSetup:0x31(1)
setup_var.efi CpuSetup:0x32(4)
setup_var.efi CpuSetup:0x36(1)
setup_var.efi CpuSetup:0x37(1)
setup_var.efi CpuSetup:0x38(4)
setup_var.efi CpuSetup:0x2C(4)
setup_var.efi CpuSetup:0x10B(2)
setup_var.efi CpuSetup:0x45(1)
setup_var.efi CpuSetup:0x236(1)
echo
echo Expected defaults: 01 00 01 00000000 00 00 00 00000000 00 00 00000000 00000000 0000 00 01
echo Cold reboot required.
pause
