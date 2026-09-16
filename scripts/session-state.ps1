[CmdletBinding()]
param([string]$Goal,[string[]]$ChangedFiles=@(),[string[]]$Verified=@(),[string[]]$Pending=@(),[string[]]$ImportantFindings=@(),[switch]$Pointer)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent; $dir = Join-Path $root '.ai-session'; $path = Join-Path $dir 'state.json'
if ($Pointer) { if (Test-Path $path) { Write-Output 'Task state is available in .ai-session/state.json; read it only if needed.' }; exit 0 }
function Limit([string[]]$items) { @($items | Where-Object { $_ } | Select-Object -First 12 | ForEach-Object { if ($_.Length -gt 180) { $_.Substring(0,180) } else { $_ } }) }
New-Item $dir -ItemType Directory -Force | Out-Null
[ordered]@{ goal=if($Goal){$Goal.Substring(0,[Math]::Min(240,$Goal.Length))}else{''}; changedFiles=Limit $ChangedFiles; verified=Limit $Verified; pending=Limit $Pending; importantFindings=Limit $ImportantFindings; updatedAt=(Get-Date).ToUniversalTime().ToString('o') } | ConvertTo-Json -Depth 4 | Set-Content $path -Encoding UTF8
