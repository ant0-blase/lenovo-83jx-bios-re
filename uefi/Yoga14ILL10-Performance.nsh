@echo -off
echo Lenovo Yoga Slim 7 14ILL10 83JX - clean performance profile
echo
echo Safe performance baseline only.
echo This does NOT change BCLK, PL1, PL2, PL4 Boost, ICCMAX, TDC, PROCHOT,
echo Thermal Monitor, VR thermal alert, voltage or load-line settings.
echo
echo ===== Current values =====
echo CPU C states / C1E / Turbo:
setup_var.efi CpuSetup:0x10(1)
setup_var.efi CpuSetup:0x11(1)
setup_var.efi CpuSetup:0x12(1)
echo Energy Efficient P-state interface:
setup_var.efi CpuSetup:0x3C(1)
echo Base Power Boot Mode:
setup_var.efi CpuSetup:0x45(1)
echo Timed MWAIT / IO MWAIT:
setup_var.efi CpuSetup:0x48(1)
setup_var.efi CpuSetup:0x49(1)
echo Package C-State Limit:
setup_var.efi CpuSetup:0x4B(1)
echo PSYS PMax:
setup_var.efi CpuSetup:0x10B(2)
echo Acoustic Noise Mitigation:
setup_var.efi CpuSetup:0x20F(1)
echo Core / GT / ATOM slow-slew selectors:
setup_var.efi CpuSetup:0x216(1)
setup_var.efi CpuSetup:0x217(1)
setup_var.efi CpuSetup:0x219(1)
echo Configurable Base Power / cTDP init:
setup_var.efi CpuSetup:0x236(1)
echo
echo ===== Apply clean performance baseline =====
echo Keep CPU power management enabled; C0/C1-only was observed to hurt Turbo.
setup_var.efi CpuSetup:0x10(1)=1
setup_var.efi CpuSetup:0x11(1)=1
setup_var.efi CpuSetup:0x12(1)=1
setup_var.efi CpuSetup:0x3C(1)=1
setup_var.efi CpuSetup:0x45(1)=0
setup_var.efi CpuSetup:0x48(1)=0
setup_var.efi CpuSetup:0x49(1)=0
setup_var.efi CpuSetup:0x4B(1)=255
setup_var.efi CpuSetup:0x10B(2)=0
setup_var.efi CpuSetup:0x20F(1)=0
setup_var.efi CpuSetup:0x216(1)=0
setup_var.efi CpuSetup:0x217(1)=0
setup_var.efi CpuSetup:0x219(1)=0
setup_var.efi CpuSetup:0x236(1)=1

echo
echo ===== Verify =====
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
echo Expected: 01 01 01 01 00 00 00 FF 0000 00 00 00 00 01
echo Run Yoga14ILL10-Battery37W-BCLK.nsh next if you want the confirmed battery/BCLK profile.
echo Cold reboot after both scripts.
pause
