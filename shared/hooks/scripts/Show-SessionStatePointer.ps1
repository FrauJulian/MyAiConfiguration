[CmdletBinding()]
param()
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (Test-Path (Join-Path $root '.ai-session/state.json')) { Write-Output 'Task state is available in .ai-session/state.json; read it only if needed.' }
