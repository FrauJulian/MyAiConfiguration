function Read-UpdateSelection {
    param([string]$HomePath, [string]$RepositoryRoot, [switch]$AllowLegacy)
    $arguments = @((Join-Path $PSScriptRoot 'selection-state.py'), 'read', '--home', $HomePath, '--manifest', (Join-Path $RepositoryRoot 'adapters/plugins.tsv'))
    if ($AllowLegacy) { $arguments += '--allow-legacy' }
    $output = & python @arguments
    if ($LASTEXITCODE -ne 0) { throw 'Could not load the saved selection.' }
    return ($output | Out-String | ConvertFrom-Json)
}

function Save-UpdateSelection {
    param([string]$HomePath, [string]$RepositoryRoot, [string]$Shell, [string]$Client, [hashtable]$Plugins,
          [Parameter(Mandatory=$true)][bool]$Flashbang, [bool]$StatusLine = $true, [bool]$SemanticRetrieval = $false)
    $arguments = @((Join-Path $PSScriptRoot 'selection-state.py'), 'write', '--home', $HomePath, '--manifest', (Join-Path $RepositoryRoot 'adapters/plugins.tsv'), '--shell', $Shell.ToLowerInvariant(), '--client', $Client.ToLowerInvariant(), '--flashbang', $Flashbang.ToString().ToLowerInvariant(), '--statusline', $StatusLine.ToString().ToLowerInvariant(), '--semantic-retrieval', $SemanticRetrieval.ToString().ToLowerInvariant(), '--selected')
    $arguments += @($Plugins.Selected | ForEach-Object { $_.name })
    $arguments += '--deselected'
    $arguments += @($Plugins.Deselected | ForEach-Object { $_.name })
    & python @arguments
    if ($LASTEXITCODE -ne 0) { throw 'Could not save the selection.' }
}
