[CmdletBinding()]
param([switch]$SkipExternal)
$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent
$failed = $false
function Pass([string]$message) { Write-Output "PASS $message" }
function Fail([string]$message) { $script:failed = $true; Write-Error "FAIL $message" -ErrorAction Continue }
function Require-Command([string]$name) { if (Get-Command $name -ErrorAction SilentlyContinue) { Pass "$name available" } else { Fail "$name is required" } }
function Version-AtLeast([string]$version, [version]$minimum) { try { return ([version]$version -ge $minimum) } catch { return $false } }
function Check-Version([string]$name, [string]$version, [version]$minimum) { if (Version-AtLeast $version $minimum) { Pass "$name $version (minimum $minimum)" } else { Fail "$name $version is below minimum $minimum" } }

Check-Version 'PowerShell' $PSVersionTable.PSVersion.ToString() ([version]'5.1')
Require-Command git; Require-Command python
if (Get-Command python -ErrorAction SilentlyContinue) {
    $pythonVersion = (& python --version 2>$null | Select-Object -First 1) -replace '^Python\s+', ''
    if ($LASTEXITCODE -eq 0) { Check-Version 'Python' $pythonVersion ([version]'3.11') } else { Fail 'Python 3.11 or newer is required' }
}
foreach ($path in @('AI-Instructions.md','shared/rules','shared/skills','shared/agents','adapters','scripts/build.sh','scripts/build.ps1','scripts/install.sh','scripts/install.ps1','scripts/update.sh','scripts/update.ps1','scripts/validate-config.py')) {
    if (Test-Path -LiteralPath (Join-Path $root $path)) { Pass "repository path $path" } else { Fail "repository path is missing: $path" }
}

if (-not $SkipExternal) {
    foreach ($client in @('codex','claude')) {
        if (Get-Command $client -ErrorAction SilentlyContinue) { & $client --version *> $null; if ($LASTEXITCODE -eq 0) { Pass "$client CLI available" } else { Fail "$client CLI could not report its version" } } else { Fail "$client CLI is required for the default setup" }
    }
    $remote = (& git -C $root config --get remote.origin.url 2>$null).Trim()
    if ([string]::IsNullOrWhiteSpace($remote)) { Fail 'Git origin remote is required for network capability checks' }
    else { & git -c http.lowSpeedLimit=1 -c http.lowSpeedTime=10 -C $root ls-remote --heads $remote *> $null; if ($LASTEXITCODE -eq 0) { Pass 'network access to the Git origin' } else { Fail 'network access to Git origin failed' } }
}

if ($failed) { Write-Error 'Capability check: FAIL'; exit 1 }
Write-Output 'Capability check: PASS'
