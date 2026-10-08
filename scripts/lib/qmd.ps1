function Sync-Qmd {
    param([Parameter(Mandatory=$true)][string]$RepositoryRoot,[Parameter(Mandatory=$true)][string]$HomePath,[ValidateSet('Codex','Claude','Both')][Parameter(Mandatory=$true)][string]$Client,[Parameter(Mandatory=$true)][bool]$Enabled,[switch]$DryRun,[switch]$Update,[switch]$Summary)
    $arguments = @((Join-Path $PSScriptRoot 'qmd.py'), 'sync', '--root', $RepositoryRoot, '--home', $HomePath, '--client', $Client.ToLowerInvariant(), '--enabled', $Enabled.ToString().ToLowerInvariant())
    if ($DryRun) { $arguments += '--dry-run' }; if ($Update) { $arguments += '--update' }
    if ($Summary) { $arguments += '--summary' }
    & python @arguments
    if ($LASTEXITCODE -ne 0) { throw 'QMD local search reconciliation failed.' }
}

function Test-QmdDevice {
    param([Parameter(Mandatory=$true)][string]$RepositoryRoot,[Parameter(Mandatory=$true)][string]$HomePath,[switch]$Summary)
    $arguments = @((Join-Path $PSScriptRoot 'qmd.py'), 'benchmark', '--root', $RepositoryRoot, '--home', $HomePath)
    if ($Summary) { $arguments += '--summary' }
    & python @arguments | Write-Host
    if ($LASTEXITCODE -eq 0) { return $true }
    if ($LASTEXITCODE -eq 2) { return $false }
    throw 'QMD benchmark failed.'
}
