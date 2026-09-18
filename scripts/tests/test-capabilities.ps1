[CmdletBinding()]
param([switch]$Summary)
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$content = Get-Content (Join-Path $root 'scripts/commands/check-capabilities.ps1') -Raw

if ($content -match '(?s)\(& \$python --version.*?Select-Object.*?\).*?\$LASTEXITCODE') {
    throw 'Python capability detection must not read $LASTEXITCODE after a pipeline.'
}

if ($Summary) { Write-Output 'Tests: PASS | capabilities' } else { Write-Output 'PASS capabilities: Python exit code is read without a pipeline' }
