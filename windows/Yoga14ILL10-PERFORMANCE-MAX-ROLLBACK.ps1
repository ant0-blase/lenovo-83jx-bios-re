# Lenovo Yoga Slim 7 14ILL10 (83JX) - PERFORMANCE MAX Windows rollback
# Run from an elevated PowerShell.
#
# PERFORMANCE-MAX modifies the currently selected Ultimate Performance plan.
# This rollback does not delete or globally reset Windows power plans. Instead it
# switches back to the built-in Balanced plan, which returns Windows HWP/PPM policy
# to its normal plan-managed behavior without destroying custom plans.

$ErrorActionPreference = 'Continue'

Write-Host 'Rolling back 83JX PERFORMANCE MAX Windows policy...'

# Built-in Windows Balanced scheme alias.
powercfg -setactive SCHEME_BALANCED

Write-Host 'Balanced power plan is active.'
Write-Host 'The modified Ultimate Performance plan is kept but is no longer active.'
Write-Host 'Use powercfg /list to inspect or delete/restore plans manually if desired.'
powercfg /getactivescheme
