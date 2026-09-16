[CmdletBinding()]
param([ValidateSet('record','summary','rotate')][string]$Action='record',[string]$Event,[string]$Agent,[string]$Role,[int]$DurationMs,[int]$ToolCalls,[string]$CommandClass,[int64]$Bytes,[int]$Count)
$ErrorActionPreference = 'Stop'; if ($env:AI_CONFIG_TELEMETRY -eq '0') { exit 0 }
$root = Split-Path $PSScriptRoot -Parent; $dir = Join-Path $root '.ai-session'; $path = Join-Path $dir 'telemetry.jsonl'; New-Item $dir -ItemType Directory -Force | Out-Null
if ($Action -eq 'rotate') { if (Test-Path $path) { Move-Item $path ($path + '.1') -Force }; exit 0 }
if ($Action -eq 'summary') { if (-not (Test-Path $path)) { Write-Output 'Telemetry: no events'; exit 0 }; $events=@(Get-Content $path | ForEach-Object { try { $_ | ConvertFrom-Json } catch {} }); $agents=@($events | Where-Object event -eq 'subagent-stop'); Write-Output ('Telemetry: {0} events | {1} subagents' -f $events.Count,$agents.Count); exit 0 }
if ([string]::IsNullOrWhiteSpace($Event)) { throw 'Event is required.' }
$record=[ordered]@{event=$Event;timestamp=(Get-Date).ToUniversalTime().ToString('o')}; foreach($pair in @(@('agent',$Agent),@('role',$Role),@('durationMs',$DurationMs),@('toolCalls',$ToolCalls),@('commandClass',$CommandClass),@('bytes',$Bytes),@('count',$Count))){if($pair[1]){$record[$pair[0]]=$pair[1]}}; ($record|ConvertTo-Json -Compress)|Add-Content $path; if((Get-Item $path).Length -gt 1048576){Move-Item $path ($path+'.1') -Force}
