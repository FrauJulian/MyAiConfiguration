function Read-UpdateSelection {
    param([string]$HomePath, [string]$RepositoryRoot)
    $output = & python (Join-Path $PSScriptRoot 'selection-state.py') read --home $HomePath --manifest (Join-Path $RepositoryRoot 'adapters/plugins.tsv')
    if ($LASTEXITCODE -ne 0) { throw 'Could not load the saved selection.' }
    return ($output | Out-String | ConvertFrom-Json)
}

function Save-UpdateSelection {
    param([string]$HomePath, [string]$RepositoryRoot, [string]$Platform, [string]$Client, [hashtable]$Plugins)
    $arguments = @((Join-Path $PSScriptRoot 'selection-state.py'), 'write', '--home', $HomePath, '--manifest', (Join-Path $RepositoryRoot 'adapters/plugins.tsv'), '--platform', $Platform.ToLowerInvariant(), '--client', $Client.ToLowerInvariant(), '--selected')
    $arguments += @($Plugins.Selected | ForEach-Object { $_.name })
    $arguments += '--deselected'
    $arguments += @($Plugins.Deselected | ForEach-Object { $_.name })
    & python @arguments
    if ($LASTEXITCODE -ne 0) { throw 'Could not save the selection.' }
}
