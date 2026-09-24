[CmdletBinding()]
param(
    [switch]$DryRun,
    [ValidateSet('Codex','Claude','Both')][string]$Client,
    [ValidateSet('PowerShell','Bash')][string]$Shell,
    [switch]$Summary
)
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $root 'scripts/lib/plugins.ps1')
. (Join-Path $root 'scripts/lib/manifest.ps1')
. (Join-Path $root 'scripts/lib/install-targets.ps1')
. (Join-Path $root 'scripts/lib/selection-state.ps1')
. (Join-Path $root 'scripts/lib/install-options.ps1')
. (Join-Path $root 'scripts/lib/semantic-retrieval.ps1')

$Shell = Read-InstallShell -Shell $Shell
$shell = $Shell.ToLowerInvariant()
$Client = Read-InstallClient -Client $Client

$homePath = [Environment]::GetFolderPath('UserProfile')
if (-not $DryRun -and (Test-AnyManifestPresent (Get-InstallDestinations -HomePath $homePath -Client $Client))) {
    throw 'Already installed, use the update script.'
}

$options = Read-InstallOptions -HomePath $homePath -RepositoryRoot $root -Client $Client -DryRun:$DryRun

$buildScript = Join-Path $root 'scripts/commands/build.ps1'
& $buildScript -Summary:$Summary
if (-not $?) { throw 'Build failed. Installation was not started.' }
$generated = Join-Path $root 'generated'
if (-not (Test-Path $generated)) { throw 'Generated output is missing after a successful build.' }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$powerShellCommand = if (Get-Command powershell -ErrorAction SilentlyContinue) { 'powershell -NoProfile -ExecutionPolicy Bypass -File' } else { 'pwsh -NoProfile -ExecutionPolicy Bypass -File' }
$shellCommand = if ($Shell -eq 'PowerShell') { $powerShellCommand } else { 'bash' }
$claudeConcurrency = if ($env:CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY) { $env:CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY } else { '5' }
if ($claudeConcurrency -notmatch '^[1-9][0-9]?$' -or [int]$claudeConcurrency -gt 10) { throw 'CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY must be an integer from 1 to 10.' }

$plugins = Select-ConfiguredPlugins -RepositoryRoot $root -HomePath $homePath -Client $Client -Mode 'Install' -DryRun:$DryRun

foreach ($item in (Get-InstallTargets -Generated $generated -HomePath $homePath -Shell $shell -Client $Client)) {
    Sync-ManagedDestination -Source $item.Source -Destination $item.Destination -Stamp $stamp `
        -AiConfigRoot $item.Destination.Replace('\','/') -ShellCommand $shellCommand -PowerShellCommand $powerShellCommand -ClaudeConcurrency $claudeConcurrency -FlashbangEnabled $options.flashbang -StatusLineEnabled $options.statusline -DryRun:$DryRun -Summary:$Summary
}

Sync-ConfiguredPlugins -RepositoryRoot $root -HomePath $homePath -Client $Client -DryRun:$DryRun -Summary:$Summary -Entries $plugins.Selected
Sync-SemanticRetrieval -RepositoryRoot $root -HomePath $homePath -Client $Client -Enabled $options.semantic_retrieval -DryRun:$DryRun -Summary:$Summary
if (-not $DryRun) { Save-UpdateSelection -HomePath $homePath -RepositoryRoot $root -Shell $Shell -Client $Client -Plugins $plugins -Flashbang $options.flashbang -StatusLine $options.statusline -SemanticRetrieval $options.semantic_retrieval }
if ($Summary) { Write-Output "Install: PASS | $Client, $Shell$(if ($DryRun) { ', dry-run' })" } else { Write-Output ($(if ($DryRun) { 'PASS install dry-run' } else { 'PASS install' })) }
exit 0
