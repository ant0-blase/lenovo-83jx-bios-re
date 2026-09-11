@echo -off
echo ============================================================
echo Lenovo Yoga Slim 7 14ILL10 (83JX)
echo Lunar Lake early PCODE 0x0A policy audit
echo ============================================================
echo.
echo READ ONLY - this script does not modify any UEFI variable.
echo.
echo Candidate Lenovo-wrapper source chain from the current reverse:
echo.
echo   CpuSetup +0x2F3 --^
echo   CpuSetup +0x2F4 ----^--^ internal CPU policy +0xF9/+0xFA/+0xFB
echo   CpuSetup +0x2F5 ------^  ^ packed into early raw PCODE command 0x0A
echo.
echo Payload construction observed in SiInitPreMemFsp:
echo.
echo   PCODE 0x0A packs internal policy +0xF9/+0xFA/+0xFB.
echo   0x2F3/0x2F4/0x2F5 are the current read-only CpuSetup source candidates.
echo   Their exact semantics are NOT proven by IFR.
echo.
echo IMPORTANT:
echo   0x2F3/0x2F4/0x2F5 are currently UNNAMED hidden CpuSetup bytes.
echo   Do NOT write them until their semantics are identified.
echo.
echo ------------------------------------------------------------
echo Hidden early-PCODE source bytes
echo ------------------------------------------------------------
echo CpuSetup +0x2F3:
setup_var.efi CpuSetup:0x2F3(1)
echo.
echo CpuSetup +0x2F4:
setup_var.efi CpuSetup:0x2F4(1)
echo.
echo CpuSetup +0x2F5:
setup_var.efi CpuSetup:0x2F5(1)
echo.
echo ------------------------------------------------------------
echo Known OC / Run-Control comparison fields
echo ------------------------------------------------------------
echo CpuSetup +0xFA  - Overclocking Lock:
setup_var.efi CpuSetup:0xFA(1)
echo.
echo CpuSetup +0xFB  - CPU Run Control:
setup_var.efi CpuSetup:0xFB(1)
echo.
echo CpuSetup +0xFC  - CPU Run Control Lock:
setup_var.efi CpuSetup:0xFC(1)
echo.
echo ------------------------------------------------------------
echo Expected interpretation
echo ------------------------------------------------------------
echo.
echo If 0x2F3 / 0x2F4 / 0x2F5 are all 00:
echo   early PCODE 0x0A DATA is inferred to be 0x000000.
echo   That makes a non-zero 0x0A payload unlikely to be the UVP lock cause.
echo.
echo If any byte is non-zero:
echo   record all three values exactly.
echo   Do NOT change them yet.
echo.
echo Current known-good OC preparation should still show:
echo   CpuSetup +0xFA = 00
echo.
echo No variable was written by this script.
echo.
pause
