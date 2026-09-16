[CmdletBinding()]
param()
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$stateDir = Join-Path $root '.ai-session'
New-Item $stateDir -ItemType Directory -Force | Out-Null
('{"event":"compact","timestamp":"' + (Get-Date).ToUniversalTime().ToString('o') + '"}') | Add-Content (Join-Path $stateDir 'telemetry.jsonl')
exit 0
