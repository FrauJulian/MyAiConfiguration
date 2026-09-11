[CmdletBinding()]
param(
    [switch]$DryRun,
    [ValidateSet('Codex','Claude','Both')][string]$Client,
    [ValidateSet('Windows','Linux')][string]$Platform,
    [switch]$UpdatePlugins
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'lib/plugins.ps1')
. (Join-Path $PSScriptRoot 'lib/manifest.ps1')
$buildScript = Join-Path $PSScriptRoot 'build.ps1'
& $buildScript
if (-not $?) { throw 'Build failed. Installation was not started.' }
$generated = Join-Path $root 'generated'
if (-not (Test-Path $generated)) { throw 'Generated output is missing after a successful build.' }

if (-not $Platform) {
    Write-Output 'Select target platform:'
    Write-Output '1) Windows'
    Write-Output '2) Linux'
    do { $platformSelection = Read-Host 'Selection [1-2]' } while ($platformSelection -notin @('1','2'))
    $Platform = @{'1'='Windows'; '2'='Linux'}[$platformSelection]
}
$platform = $Platform.ToLowerInvariant()

if (-not $Client) {
    Write-Output 'Select installation target:'
    Write-Output '1) Codex'
    Write-Output '2) Claude'
    Write-Output '3) Both'
    do { $selection = Read-Host 'Selection [1-3]' } while ($selection -notin @('1','2','3'))
    $Client = @{'1'='Codex'; '2'='Claude'; '3'='Both'}[$selection]
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$homePath = [Environment]::GetFolderPath('UserProfile')
$shellCommand = 'pwsh -NoProfile -ExecutionPolicy Bypass -File'
$windowsShellCommand = 'powershell -NoProfile -ExecutionPolicy Bypass -File'
if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { $shellCommand = $windowsShellCommand }
$targets = @()
if ($Client -in @('Codex','Both')) { $targets += @{ Source=(Join-Path $generated "codex-$platform"); Destination=(Join-Path $homePath '.codex') } }
if ($Client -in @('Codex','Both')) { $targets += @{ Source=(Join-Path $generated "codex-$platform/skills"); Destination=(Join-Path $homePath '.agents/skills') } }
if ($Client -in @('Claude','Both')) { $targets += @{ Source=(Join-Path $generated "claude-$platform"); Destination=(Join-Path $homePath '.claude') } }

foreach ($item in $targets) {
    Sync-ManagedDestination -Source $item.Source -Destination $item.Destination -Stamp $stamp `
        -AiConfigRoot $item.Destination.Replace('\','/') -ShellCommand $shellCommand -WindowsShellCommand $windowsShellCommand -DryRun:$DryRun
}

Install-ConfiguredPlugins -RepositoryRoot $root -Client $Client -DryRun:$DryRun -Update:$UpdatePlugins
Write-Output ($(if ($DryRun) { 'PASS install dry-run' } else { 'PASS install' }))
exit 0
