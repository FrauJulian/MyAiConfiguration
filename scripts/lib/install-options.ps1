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
    $defaults = @{ update_agents = $false; flashbang = $true; semantic_retrieval = $false }
    if (Test-Path -LiteralPath (Join-Path $HomePath '.my-ai-configuration/selection.json')) {
        try { $defaults = Read-UpdateSelection -HomePath $HomePath -RepositoryRoot $RepositoryRoot -AllowLegacy }
        catch { Write-Warning 'Saved options could not be read; confirm new options below.' }
    }
    if ($DryRun) { return $defaults }
    return @{
        update_agents = Read-InstallBoolean -Prompt "Update selected agent CLIs ($Client)?" -Default $defaults.update_agents
        flashbang = Read-InstallBoolean -Prompt 'Enable the Flashbang notification hook?' -Default $defaults.flashbang
        semantic_retrieval = Read-InstallBoolean -Prompt 'Enable Qwen3 embedding and reranking semantic retrieval?' -Default $defaults.semantic_retrieval
    }
}

function Test-CodexProcessActive {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { return $false }
    return [bool](Get-Process -Name 'codex' -ErrorAction SilentlyContinue)
}

function Test-GlobalNpmCodex {
    $npm = Get-Command npm -ErrorAction SilentlyContinue
    if (-not $npm) { return $false }
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $npm list -g '@openai/codex' --depth=0 --json 1>$null 2>$null
        return $LASTEXITCODE -eq 0
    } finally {
        $ErrorActionPreference = $previousPreference
    }
}

function Update-SelectedAgentClis {
    param([string]$Client, [switch]$DryRun, [switch]$Summary)
    $clients = if ($Client -eq 'Both') { @('codex', 'claude') } else { @($Client.ToLowerInvariant()) }
    $previousNonInteractive = $script:PluginNonInteractive
    $previousAutoUpdate = $env:CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE
    try {
        $script:PluginNonInteractive = $true
        $env:CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE = '1'
        foreach ($selectedClient in $clients) {
            if ($selectedClient -eq 'codex' -and -not $DryRun -and (Test-CodexProcessActive)) {
                Write-Warning 'Codex CLI update skipped because codex.exe is running. Close all Codex sessions and run the update again to update the CLI.'
                continue
            }
            if ($selectedClient -eq 'codex' -and (Test-GlobalNpmCodex)) {
                Invoke-PluginCommand -Command 'npm' -Arguments @('install','-g','@openai/codex@latest') -DryRun:$DryRun -Summary:$Summary
            } else {
                Invoke-PluginCommand -Command $selectedClient -Arguments @('update') -DryRun:$DryRun -Summary:$Summary
            }
            if ($Summary) { Write-Output "CLI $selectedClient update: $(if ($DryRun) { 'dry-run' } else { 'PASS' })" }
        }
    } finally {
        $script:PluginNonInteractive = $previousNonInteractive
        $env:CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE = $previousAutoUpdate
    }
}
