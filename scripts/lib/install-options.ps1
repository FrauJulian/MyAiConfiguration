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

function Test-GlobalNpmPackage {
    param([Parameter(Mandatory=$true)][string]$Package)
    $npm = Get-Command npm -ErrorAction SilentlyContinue
    if (-not $npm) { return $false }
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $npm list -g $Package --depth=0 --json 1>$null 2>$null
        return $LASTEXITCODE -eq 0
    } finally {
        $ErrorActionPreference = $previousPreference
    }
}

function Get-CliNpmPackage {
    param([ValidateSet('codex','claude')][Parameter(Mandatory=$true)][string]$Client)
    if ($Client -eq 'codex') { return '@openai/codex' }
    return '@anthropic-ai/claude-code'
}

function Read-CliReinstallOption {
    <#
    .SYNOPSIS
        Asked once per install run, never persisted; a dry run never prompts and never previews it.
    #>
    param([string]$Client, [switch]$DryRun)
    if ($DryRun) { return $false }
    return Read-InstallBoolean -Prompt "Uninstall $Client and reinstall via npm?" -Default $false
}

function Invoke-CliReinstall {
    param([string]$Client, [switch]$DryRun, [switch]$Summary)
    $clients = if ($Client -eq 'Both') { @('codex', 'claude') } else { @($Client.ToLowerInvariant()) }
    $previousAutoUpdate = $env:CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE
    try {
        $env:CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE = '1'
        foreach ($selectedClient in $clients) {
            if ($selectedClient -eq 'codex' -and -not $DryRun -and (Test-CodexProcessActive)) {
                Write-Warning 'Codex CLI reinstall skipped because codex.exe is running. Close all Codex sessions and run install again to reinstall the CLI.'
                continue
            }
            $package = Get-CliNpmPackage -Client $selectedClient
            if (Test-GlobalNpmPackage -Package $package) {
                Invoke-PluginCommand -Command 'npm' -Arguments @('uninstall', '-g', $package) -DryRun:$DryRun -Summary:$Summary
            } else {
                Write-Warning "$selectedClient CLI was not found as a global npm package; a non-npm installation cannot be removed automatically. Installing $package via npm alongside it."
            }
            Invoke-PluginCommand -Command 'npm' -Arguments @('install', '-g', "$package@latest") -DryRun:$DryRun -Summary:$Summary
            if ($Summary) { Write-Output "CLI $selectedClient reinstall: $(if ($DryRun) { 'dry-run' } else { 'PASS' })" }
        }
    } finally {
        $env:CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE = $previousAutoUpdate
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
