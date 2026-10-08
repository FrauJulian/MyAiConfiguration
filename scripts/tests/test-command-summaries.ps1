[CmdletBinding()]
param([switch]$Summary)
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$doctorPath = Join-Path $root 'scripts/commands/doctor.ps1'
$doctorAst = [System.Management.Automation.Language.Parser]::ParseFile($doctorPath, [ref]$null, [ref]$null)
$probe = $doctorAst.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-DoctorCommand' }, $true)
if (-not $probe) { throw 'Doctor command probe is missing.' }
Invoke-Expression $probe.Extent.Text
foreach ($code in @(0, 7)) {
    $result = Invoke-DoctorCommand -Command 'python' -Arguments @('-c', "import sys; print('fixture 1.0'); print('fixture warning', file=sys.stderr); sys.exit($code)")
    if ($result.ExitCode -ne $code -or ($result.Output -join ' ') -notmatch 'fixture warning' -or ($result.Output -join ' ') -notmatch 'fixture 1.0') { throw 'Doctor must capture native warnings and preserve the exit code.' }
    if ($ErrorActionPreference -ne 'Stop') { throw 'Doctor command probe changed the caller error preference.' }
}
$missing = Invoke-DoctorCommand -Command 'ai-config-missing-doctor-test-command'
if ($missing.ExitCode -eq 0) { throw 'Doctor must not report a missing command as successful.' }
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
