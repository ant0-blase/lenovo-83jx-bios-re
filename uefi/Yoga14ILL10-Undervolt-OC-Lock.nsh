@echo -off

echo ============================================================
echo Lenovo Yoga Slim 7 14ILL10 (83JX) - Undervolt preparation
echo ============================================================
echo.
echo This script only clears the CpuSetup Overclocking Lock.
echo It does NOT change voltage offsets, UVP, power limits,
echo PROCHOT, thermal protection, ICCMAX, TDC or VR settings.
echo.
echo Target:
echo   CpuSetup + 0xFA = Overclocking Lock
echo   wanted value    = 00
echo.

echo ===== Current value =====
setup_var.efi CpuSetup:0xFA(1)
echo.

echo ===== Clear Overclocking Lock =====
setup_var.efi CpuSetup:0xFA(1)=0
echo.

echo ===== Verify =====
setup_var.efi CpuSetup:0xFA(1)
echo.

echo Expected final value:
echo   00
echo.
echo After this script:
echo   1. Power the machine off completely.
echo   2. Cold boot into Linux.
echo   3. Check MSR 0x194 bit20 and MSR 0x195.
echo   4. Re-run lnl-uvp-pcode disable-test only if OC Lock is 0.
echo.
pause
