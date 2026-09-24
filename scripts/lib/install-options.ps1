function Read-InstallBoolean {
    param([string]$Prompt, [bool]$Default)
    $hint = if ($Default) { 'Y/n' } else { 'y/N' }
    while ($true) {
        Write-Host "$Prompt [$hint] " -NoNewline
        $answer = [Console]::ReadLine()
        if ($null -eq $answer) { throw 'Input ended before install options were confirmed.' }
        switch ($answer.Trim().ToLowerInvariant()) {
            '' { return $Default }
            { $_ -in @('y', 'yes') } { return $true }
            { $_ -in @('n', 'no') } { return $false }
        }
    }
}

function Read-InstallOptions {
    param([string]$HomePath, [string]$RepositoryRoot, [string]$Client, [switch]$DryRun)
    $defaults = @{ flashbang = $true; statusline = $true; semantic_retrieval = $false }
    if (Test-Path -LiteralPath (Join-Path $HomePath '.my-ai-configuration/selection.json')) {
        try { $defaults = Read-UpdateSelection -HomePath $HomePath -RepositoryRoot $RepositoryRoot -AllowLegacy }
        catch { Write-Warning 'Saved options could not be read; confirm new options below.' }
    }
    if ($DryRun) { return $defaults }
    return @{
        flashbang = Read-InstallBoolean -Prompt 'Enable the Flashbang notification hook?' -Default $defaults.flashbang
        statusline = Read-InstallBoolean -Prompt 'Apply the custom status line?' -Default $defaults.statusline
        semantic_retrieval = Read-SemanticRetrievalOption -Default $defaults.semantic_retrieval -RepositoryRoot $RepositoryRoot -HomePath $HomePath
    }
}

function Read-SemanticRetrievalOption {
    param([bool]$Default,[string]$RepositoryRoot,[string]$HomePath)
    $hint = if ($Default) { 'Y/n/a' } else { 'y/N/a' }
    while ($true) {
        Write-Host "Enable Qwen3 embedding and reranking semantic retrieval? [$hint] " -NoNewline
        $answer = [Console]::ReadLine()
        if ($null -eq $answer) { throw 'Input ended before semantic retrieval was confirmed.' }
        switch ($answer.Trim().ToLowerInvariant()) {
            '' { return $Default }
            { $_ -in @('y', 'yes') } { return $true }
            { $_ -in @('n', 'no') } { return $false }
            { $_ -in @('a', 'auto') } { return Test-SemanticRetrievalDevice -RepositoryRoot $RepositoryRoot -HomePath $HomePath }
        }
    }
}
