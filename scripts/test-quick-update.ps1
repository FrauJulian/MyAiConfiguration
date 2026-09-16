[CmdletBinding()]
param([switch]$Summary)
$ErrorActionPreference = 'Stop'
& python (Join-Path $PSScriptRoot 'test-quick-update.py')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Output 'Tests: PASS | quick update selection'
