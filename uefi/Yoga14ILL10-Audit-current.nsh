@echo -off
echo Lenovo Yoga Slim 7 14ILL10 83JX - final profile audit
echo READ ONLY - no values are written.
echo
echo ===== Performance =====
setup_var.efi CpuSetup:0x10(1)
setup_var.efi CpuSetup:0x11(1)
setup_var.efi CpuSetup:0x12(1)
setup_var.efi CpuSetup:0x3C(1)
setup_var.efi CpuSetup:0x45(1)
setup_var.efi CpuSetup:0x48(1)
setup_var.efi CpuSetup:0x49(1)
setup_var.efi CpuSetup:0x4B(1)
setup_var.efi CpuSetup:0x10B(2)
setup_var.efi CpuSetup:0x20F(1)
setup_var.efi CpuSetup:0x216(1)
setup_var.efi CpuSetup:0x217(1)
setup_var.efi CpuSetup:0x219(1)
setup_var.efi CpuSetup:0x236(1)
echo
echo ===== Battery 37W + BCLK =====
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
echo
echo Final working target:
echo performance 01 01 01 01 00 00 00 FF 0000 00 00 00 00 01
echo BCLK/battery 00 00 00 00009088 01 00 01 00009088 00 01 00009088 0000F618
pause
