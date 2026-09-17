function Sync-SemanticRetrieval {
    param([Parameter(Mandatory=$true)][string]$RepositoryRoot,[Parameter(Mandatory=$true)][string]$HomePath,[ValidateSet('Codex','Claude','Both')][Parameter(Mandatory=$true)][string]$Client,[Parameter(Mandatory=$true)][bool]$Enabled,[switch]$DryRun,[switch]$Update,[switch]$Summary)
    $statePath = Join-Path $HomePath '.my-ai-configuration/semantic-retrieval.json'
    if (-not $Enabled -and -not (Test-Path -LiteralPath $statePath)) { return }
    $arguments = @((Join-Path $PSScriptRoot 'semantic-retrieval.py'), 'sync', '--root', $RepositoryRoot, '--home', $HomePath, '--client', $Client.ToLowerInvariant(), '--enabled', $Enabled.ToString().ToLowerInvariant())
    if ($DryRun) { $arguments += '--dry-run' }; if ($Update) { $arguments += '--update' }
    & python @arguments
    if ($LASTEXITCODE -ne 0) { throw 'Semantic retrieval reconciliation failed.' }
}
