# Lenovo Yoga Slim 7 14ILL10 (83JX) - PERFORMANCE MAX Windows power policy
# Run in an elevated PowerShell after selecting the Ultimate Performance plan.
#
# AC: keep the known-good maximum-performance policy that fixed the Windows-only
#     low-power / ~8 W behavior on this machine.
# DC: preserve battery life with dynamic HWP scaling, moderate EPP and core parking
#     while still allowing 100% maximum processor performance for short bursts.

$ErrorActionPreference = 'Continue'

Write-Host 'Applying 83JX PERFORMANCE MAX Windows policy...'

# -----------------------------------------------------------------------------
# AC / plugged in: maximum performance and the known-good anti-8W policy.
# -----------------------------------------------------------------------------
powercfg -setacvalueindex scheme_current sub_processor PROCTHROTTLEMIN 100
powercfg -setacvalueindex scheme_current sub_processor PROCTHROTTLEMAX 100
powercfg -setacvalueindex scheme_current sub_processor PERFEPP 0

powercfg -setacvalueindex scheme_current sub_processor PROCTHROTTLEMIN1 100
powercfg -setacvalueindex scheme_current sub_processor PROCTHROTTLEMAX1 100
powercfg -setacvalueindex scheme_current sub_processor PERFEPP1 0

powercfg -setacvalueindex scheme_current sub_processor CPMINCORES 100
powercfg -setacvalueindex scheme_current sub_processor CPMINCORES1 100
powercfg -setacvalueindex scheme_current sub_processor PERFBOOSTMODE 2

# -----------------------------------------------------------------------------
# DC / battery: efficient HWP policy.
# Keep max=100 so short bursts are not capped, but let Lunar Lake idle/park normally.
# EPP 128 = balanced efficiency preference; boost mode 4 = Efficient Aggressive.
# -----------------------------------------------------------------------------
powercfg -setdcvalueindex scheme_current sub_processor PROCTHROTTLEMIN 5
powercfg -setdcvalueindex scheme_current sub_processor PROCTHROTTLEMAX 100
powercfg -setdcvalueindex scheme_current sub_processor PERFEPP 128

powercfg -setdcvalueindex scheme_current sub_processor PROCTHROTTLEMIN1 5
powercfg -setdcvalueindex scheme_current sub_processor PROCTHROTTLEMAX1 100
powercfg -setdcvalueindex scheme_current sub_processor PERFEPP1 128

powercfg -setdcvalueindex scheme_current sub_processor CPMINCORES 10
powercfg -setdcvalueindex scheme_current sub_processor CPMINCORES1 10
powercfg -setdcvalueindex scheme_current sub_processor PERFBOOSTMODE 4

powercfg -setactive scheme_current

Write-Host 'Done.'
Write-Host 'AC: min/max 100, EPP 0, all cores unparked, aggressive boost.'
Write-Host 'DC: min 5, max 100, EPP 128, 10% minimum unparked cores, efficient-aggressive boost.'
powercfg /getactivescheme
