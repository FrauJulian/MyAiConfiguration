[CmdletBinding()]
param()
$ErrorActionPreference = 'Continue'
$failed = $false
function Pass([string]$message) { Write-Output "PASS $message" }
function Fail([string]$message) { $script:failed = $true; Write-Error "FAIL $message" -ErrorAction Continue }
function Require-Command([string]$name) { if (Get-Command $name -ErrorAction SilentlyContinue) { Pass "$name available" } else { Fail "$name is required" } }
function Version-AtLeast([string]$version, [version]$minimum) { try { return ([version]$version -ge $minimum) } catch { return $false } }
function Check-Version([string]$name, [string]$version, [version]$minimum) { if (Version-AtLeast $version $minimum) { Pass "$name $version (minimum $minimum)" } else { Fail "$name $version is below minimum $minimum" } }

Check-Version 'PowerShell' $PSVersionTable.PSVersion.ToString() ([version]'5.1')
Require-Command jq; Require-Command python
if (Get-Command python -ErrorAction SilentlyContinue) {
    $pythonVersion = (& python --version 2>$null | Select-Object -First 1) -replace '^Python\s+', ''
    if ($LASTEXITCODE -eq 0) { Check-Version 'Python' $pythonVersion ([version]'3.11') } else { Fail 'Python 3.11 or newer is required' }
}

if ($failed) { Write-Error 'Capability check: FAIL'; exit 1 }
Write-Output 'Capability check: PASS'
