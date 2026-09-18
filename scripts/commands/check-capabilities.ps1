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
Require-Command jq
$pythonVersion = $null
foreach ($python in @('python', 'python3')) {
    if (-not (Get-Command $python -ErrorAction SilentlyContinue)) { continue }
    $candidate = & $python --version 2>$null
    $pythonExitCode = $LASTEXITCODE
    if ($pythonExitCode -eq 0) { $pythonVersion = $candidate -replace '^Python\s+', ''; break }
}
if ($null -ne $pythonVersion) { Check-Version 'Python' $pythonVersion ([version]'3.11') } else { Fail 'Python 3.11 or newer is required' }

if ($failed) { Write-Error 'Capability check: FAIL'; exit 1 }
Write-Output 'Capability check: PASS'
