[CmdletBinding()]
param(
    [switch]$DryRun,
    [ValidateSet('Codex','Claude','Both')][string]$Client,
    [switch]$Force,
    [switch]$Summary
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'lib/plugins.ps1')
. (Join-Path $PSScriptRoot 'lib/manifest.ps1')
. (Join-Path $PSScriptRoot 'lib/install-targets.ps1')
. (Join-Path $PSScriptRoot 'lib/semantic-retrieval.ps1')

$Client = Read-InstallClient -Client $Client
$homePath = [Environment]::GetFolderPath('UserProfile')
$generated = Join-Path $root 'generated'
$targets = @(Get-InstallTargets -Generated $generated -HomePath $homePath -Shell 'bash' -Client $Client)
$installedTargets = @($targets | Where-Object { Test-Path -LiteralPath (Get-ManagedManifestPath $_.Destination) })

if (-not $DryRun -and $installedTargets.Count -eq 0) { throw 'Not installed, nothing to uninstall.' }

if (-not $DryRun -and -not $Force) {
    if ([Console]::IsInputRedirected -or $env:CI -eq 'true' -or $env:AI_CONFIG_NO_INTERACTIVE -eq '1') {
        throw 'Refusing to uninstall without confirmation in a non-interactive session. Pass -Force to proceed.'
    }
    Write-Host "This removes the managed configuration, extensions, and semantic retrieval setup for $Client under $homePath."
    Write-Host 'Backups already on disk are kept; anything this setup never installed is left untouched.'
    $confirm = Read-Host -Prompt 'Continue? [y/N]'
    if ($null -eq $confirm) { $confirm = '' }
    if ($confirm.Trim().ToLowerInvariant() -notin @('y', 'yes')) {
        Write-Output 'Cancelled, nothing was removed.'
        exit 1
    }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$emptySource = Join-Path ([System.IO.Path]::GetTempPath()) "ai-config-uninstall-$stamp"
New-Item $emptySource -ItemType Directory -Force | Out-Null
try {
    foreach ($item in $targets) {
        if (-not (Test-Path -LiteralPath (Get-ManagedManifestPath $item.Destination))) {
            if (-not $Summary) { Write-Output "SKIP $($item.Destination) (not installed)" }
            continue
        }
        Sync-ManagedDestination -Source $emptySource -Destination $item.Destination -Stamp $stamp `
            -AiConfigRoot $item.Destination.Replace('\','/') -ShellCommand '' -PowerShellCommand '' -DryRun:$DryRun -Summary:$Summary
        if (-not $DryRun) {
            Remove-Item -LiteralPath (Get-ManagedManifestPath $item.Destination) -Force -ErrorAction SilentlyContinue
            if (@(Get-ChildItem -LiteralPath $item.Destination -Force -ErrorAction SilentlyContinue).Count -eq 0) {
                Remove-Item -LiteralPath $item.Destination -Force -ErrorAction SilentlyContinue
            }
        }
    }
} finally {
    Remove-Item -LiteralPath $emptySource -Recurse -Force -ErrorAction SilentlyContinue
}

Sync-ConfiguredPlugins -RepositoryRoot $root -HomePath $homePath -Client $Client -DryRun:$DryRun -Summary:$Summary -Entries @()
Sync-SemanticRetrieval -RepositoryRoot $root -HomePath $homePath -Client $Client -Enabled $false -DryRun:$DryRun -Summary:$Summary

if (-not $DryRun) {
    $remaining = @($targets | Where-Object { Test-Path -LiteralPath (Get-ManagedManifestPath $_.Destination) })
    if ($remaining.Count -eq 0) {
        $configRoot = Join-Path $homePath '.my-ai-configuration'
        $selectionPath = Join-Path $configRoot 'selection.json'
        if (Test-Path -LiteralPath $selectionPath) { Remove-Item -LiteralPath $selectionPath -Force }
        if ((Test-Path -LiteralPath $configRoot) -and @(Get-ChildItem -LiteralPath $configRoot -Force -ErrorAction SilentlyContinue).Count -eq 0) {
            Remove-Item -LiteralPath $configRoot -Force -ErrorAction SilentlyContinue
        }
    }
}

if ($Summary) { Write-Output "Uninstall: PASS | $Client$(if ($DryRun) { ', dry-run' })" } else { Write-Output ($(if ($DryRun) { 'PASS uninstall dry-run' } else { 'PASS uninstall' })) }
exit 0
