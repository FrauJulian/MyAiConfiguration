[CmdletBinding()]
param([switch]$Summary)
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$doctorSummaryOutput = & (Join-Path $root 'scripts/commands/doctor.ps1') -Summary
if (@($doctorSummaryOutput | Where-Object { $_ -match '^PASS ' }).Count -ne 0) { throw 'Doctor summary mode must not print individual PASS lines.' }
if (@($doctorSummaryOutput | Where-Object { $_ -match '^Doctor: PASS \| \d+ checks$' }).Count -ne 1) { throw "Doctor summary mode must print one 'Doctor: PASS | N checks' line: $($doctorSummaryOutput -join '; ')" }
foreach ($entryPoint in @('install','update')) {
    $preview = @(& (Join-Path $root "scripts/commands/$entryPoint.ps1") -Summary -DryRun -Client Both -Shell PowerShell)
    if ($preview -match '^(SOURCE|CREATE|UPDATE|UNCHANGED|BACKUP|DRYRUN|PASS) ') { throw "$entryPoint summary leaked per-item output." }
    if (@($preview | Where-Object { $_ -match ('^' + $entryPoint + ': PASS') }).Count -ne 1) { throw "$entryPoint summary is missing." }
}
$doctorSummaryOutput | Where-Object { $_ -match '^WARN ' }
if ($Summary) { Write-Output 'Tests: PASS | command summaries' } else { Write-Output 'PASS doctor, install, and update summaries' }
exit 0
