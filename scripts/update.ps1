[CmdletBinding()]
param(
    [switch]$DryRun,
    [ValidateSet('Codex','Claude','Both')][string]$Client,
    [ValidateSet('Windows','Linux')][string]$Platform,
    [switch]$Summary
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'lib/plugins.ps1')
. (Join-Path $PSScriptRoot 'lib/manifest.ps1')
. (Join-Path $PSScriptRoot 'lib/install-targets.ps1')

$Platform = Read-InstallPlatform -Platform $Platform
$platform = $Platform.ToLowerInvariant()
$Client = Read-InstallClient -Client $Client

$homePath = [Environment]::GetFolderPath('UserProfile')
if (-not $DryRun -and -not (Test-AllManifestsPresent (Get-InstallDestinations -HomePath $homePath -Client $Client))) {
    throw 'Not installed, use the install script.'
}

$buildScript = Join-Path $PSScriptRoot 'build.ps1'
& $buildScript -Summary:$Summary
if (-not $?) { throw 'Build failed. Update was not started.' }
$generated = Join-Path $root 'generated'
if (-not (Test-Path $generated)) { throw 'Generated output is missing after a successful build.' }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$shellCommand = 'pwsh -NoProfile -ExecutionPolicy Bypass -File'
$windowsShellCommand = 'powershell -NoProfile -ExecutionPolicy Bypass -File'
if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { $shellCommand = $windowsShellCommand }

foreach ($item in (Get-InstallTargets -Generated $generated -HomePath $homePath -Platform $platform -Client $Client)) {
    Sync-ManagedDestination -Source $item.Source -Destination $item.Destination -Stamp $stamp `
        -AiConfigRoot $item.Destination.Replace('\','/') -ShellCommand $shellCommand -WindowsShellCommand $windowsShellCommand -DryRun:$DryRun -Summary:$Summary
}

$plugins = Select-ConfiguredPlugins -RepositoryRoot $root -Client $Client -Mode 'Update' -DryRun:$DryRun
Install-ConfiguredPlugins -RepositoryRoot $root -Client $Client -DryRun:$DryRun -Update -Summary:$Summary -Entries $plugins.Selected
Uninstall-DeselectedPlugins -Entries $plugins.Deselected -Client $Client -DryRun:$DryRun -Summary:$Summary
if ($Summary) { Write-Output "Update: PASS | $Client, $Platform$(if ($DryRun) { ', dry-run' })" } else { Write-Output ($(if ($DryRun) { 'PASS update dry-run' } else { 'PASS update' })) }
exit 0
