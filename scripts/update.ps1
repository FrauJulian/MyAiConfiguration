[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Quick,
    [ValidateSet('Codex','Claude','Both')][string]$Client,
    [ValidateSet('PowerShell','Bash')][string]$Shell,
    [switch]$Summary
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'lib/plugins.ps1')
. (Join-Path $PSScriptRoot 'lib/manifest.ps1')
. (Join-Path $PSScriptRoot 'lib/install-targets.ps1')
. (Join-Path $PSScriptRoot 'lib/selection-state.ps1')
. (Join-Path $PSScriptRoot 'lib/install-options.ps1')

$homePath = [Environment]::GetFolderPath('UserProfile')
if ($Quick) {
    $saved = Read-UpdateSelection -HomePath $homePath -RepositoryRoot $root
    if (-not $Shell) { $Shell = $saved.shell }
    if (-not $Client) { $Client = $saved.client }
}

$Shell = Read-InstallShell -Shell $Shell
$shell = $Shell.ToLowerInvariant()
$Client = Read-InstallClient -Client $Client

if (-not $DryRun -and -not (Test-AllManifestsPresent (Get-InstallDestinations -HomePath $homePath -Client $Client))) {
    throw 'Not installed, use the install script.'
}

$options = if ($Quick) { $saved } else { Read-InstallOptions -HomePath $homePath -RepositoryRoot $root -Client $Client -DryRun:$DryRun }

$buildScript = Join-Path $PSScriptRoot 'build.ps1'
& $buildScript -Summary:$Summary
if (-not $?) { throw 'Build failed. Update was not started.' }
$generated = Join-Path $root 'generated'
if (-not (Test-Path $generated)) { throw 'Generated output is missing after a successful build.' }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$powerShellCommand = if (Get-Command powershell -ErrorAction SilentlyContinue) { 'powershell -NoProfile -ExecutionPolicy Bypass -File' } else { 'pwsh -NoProfile -ExecutionPolicy Bypass -File' }
$shellCommand = if ($Shell -eq 'PowerShell') { $powerShellCommand } else { 'bash' }

$plugins = if ($Quick) {
    $entries = @(Get-ConfiguredPluginEntries -RepositoryRoot $root)
    @{ Selected = @($entries | Where-Object { $saved.selected -contains $_.name }); Deselected = @($entries | Where-Object { $saved.deselected -contains $_.name }) }
} else {
    Select-ConfiguredPlugins -RepositoryRoot $root -HomePath $homePath -Client $Client -Mode 'Update' -DryRun:$DryRun
}

if ($options.update_agents) { Update-SelectedAgentClis -Client $Client -DryRun:$DryRun -Summary:$Summary }

foreach ($item in (Get-InstallTargets -Generated $generated -HomePath $homePath -Shell $shell -Client $Client)) {
    Sync-ManagedDestination -Source $item.Source -Destination $item.Destination -Stamp $stamp `
        -AiConfigRoot $item.Destination.Replace('\','/') -ShellCommand $shellCommand -PowerShellCommand $powerShellCommand -FlashbangEnabled $options.flashbang -DryRun:$DryRun -Summary:$Summary
}

$previousPluginNonInteractive = $script:PluginNonInteractive
$previousCI = $env:CI
try {
    $script:PluginNonInteractive = [bool]$Quick
    if ($Quick) { $env:CI = 'true' }
    Sync-ConfiguredPlugins -RepositoryRoot $root -HomePath $homePath -Client $Client -DryRun:$DryRun -Update -Summary:$Summary -Entries $plugins.Selected
} finally {
    $script:PluginNonInteractive = $previousPluginNonInteractive
    $env:CI = $previousCI
}
if (-not $DryRun) { Save-UpdateSelection -HomePath $homePath -RepositoryRoot $root -Shell $Shell -Client $Client -Plugins $plugins -UpdateAgents $options.update_agents -Flashbang $options.flashbang }
if ($Summary) { Write-Output "Update: PASS | $Client, $Shell$(if ($DryRun) { ', dry-run' })" } else { Write-Output ($(if ($DryRun) { 'PASS update dry-run' } else { 'PASS update' })) }
exit 0
