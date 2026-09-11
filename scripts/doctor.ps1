[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$homePath = [Environment]::GetFolderPath('UserProfile')
$fail = $false
function Result($state, $message) { Write-Output ("$state $message"); if ($state -eq 'FAIL') { $script:fail = $true } }
foreach ($tool in @('codex','claude')) { if (Get-Command $tool -ErrorAction SilentlyContinue) { $version = & $tool --version 2>&1 | Select-Object -First 1; Result 'PASS' "$tool available ($version)" } else { Result 'WARN' "$tool unavailable" } }
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) { if (Get-Command jq -ErrorAction SilentlyContinue) { Result 'PASS' 'jq available for Claude status line' } else { Result 'WARN' 'jq unavailable; Claude status line is disabled' } }
foreach ($platform in @('windows','linux')) {
if (Test-Path (Join-Path $root "generated/codex-$platform/AGENTS.md")) { Result 'PASS' 'generated output present' } else { Result 'FAIL' 'generated output missing; run build' }
if ((Test-Path (Join-Path $root "generated/codex-$platform/hooks/scripts/Validate-CommandSafety.ps1")) -and (Test-Path (Join-Path $root "generated/codex-$platform/hooks/scripts/validate-command-safety.sh")) -and (Test-Path (Join-Path $root "generated/claude-$platform/hooks/scripts/Validate-CommandSafety.ps1")) -and (Test-Path (Join-Path $root "generated/claude-$platform/hooks/scripts/validate-command-safety.sh"))) { Result 'PASS' 'generated hooks present' } else { Result 'FAIL' 'generated hooks missing; run build' }
}
foreach ($path in @('.codex/AGENTS.md','.codex/config.toml','.claude/CLAUDE.md','.claude/settings.json')) { if (Test-Path (Join-Path $homePath $path)) { Result 'PASS' "installed $path" } else { Result 'WARN' "not installed $path" } }
foreach ($path in @('shared/rules','shared/skills','shared/agents','shared/hooks/scripts')) { if (Test-Path (Join-Path $root $path)) { Result 'PASS' "source $path" } else { Result 'FAIL' "missing $path" } }
if ($fail) { exit 1 }
Write-Output 'PASS doctor'
