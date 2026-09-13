function Invoke-PluginCommand {
    param(
        [Parameter(Mandatory=$true)][string]$Command,
        [Parameter(Mandatory=$true)][string[]]$Arguments,
        [switch]$DryRun
    )
    $display = "$Command $($Arguments -join ' ')"
    if ($DryRun) { Write-Output "DRYRUN $display"; return }
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Plugin command failed: $display" }
}

function Get-ConfiguredPluginEntries {
    param([Parameter(Mandatory=$true)][string]$RepositoryRoot)
    $manifest = Join-Path $RepositoryRoot 'adapters/plugins.tsv'
    if (-not (Test-Path -LiteralPath $manifest)) { throw "Plugin manifest is missing: $manifest" }
    Import-Csv -LiteralPath $manifest -Delimiter ([char]9) | ForEach-Object {
        $_.claude_plugin = $_.claude_plugin.Trim()
        $_.codex_plugin = $_.codex_plugin.Trim()
        $_
    }
}

function Get-InstalledPlugins {
    param([ValidateSet('Claude','Codex')][string]$Client)
    if ($Client -eq 'Claude') {
        if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { throw 'Claude Code CLI is required to manage Claude plugins.' }
        $items = (claude plugin list --json | Out-String) | ConvertFrom-Json
        return @($items)
    }
    if (-not (Get-Command codex -ErrorAction SilentlyContinue)) { throw 'Codex CLI is required to manage Codex plugins.' }
    $items = (codex plugin list --json | Out-String) | ConvertFrom-Json
    return @($items.installed)
}

function Ensure-CodexMarketplace {
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$MarketplaceName,
        [switch]$DryRun
    )
    if ($DryRun) {
        Write-Output "DRYRUN codex plugin marketplace add $Source"
        return
    }
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& codex plugin marketplace add $Source 2>&1)
        $exitCode = $LASTEXITCODE
    } catch {
        $output = @($_)
        $exitCode = 1
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    $output | ForEach-Object { Write-Output $_ }
    if ($exitCode -eq 0) { return }

    $text = $output -join [Environment]::NewLine
    if ($text -match 'marketplace .* already added from a different source') {
        Write-Output "WARN Codex marketplace '$MarketplaceName' exists from another source; replacing it with: $Source"
        Invoke-PluginCommand -Command 'codex' -Arguments @('plugin','marketplace','remove',$MarketplaceName)
        Invoke-PluginCommand -Command 'codex' -Arguments @('plugin','marketplace','add',$Source)
        return
    }
    throw "Plugin command failed: codex plugin marketplace add $Source"
}

function Install-ConfiguredPlugins {
    param(
        [Parameter(Mandatory=$true)][string]$RepositoryRoot,
        [ValidateSet('Codex','Claude','Both')][Parameter(Mandatory=$true)][string]$Client,
        [switch]$DryRun,
        [switch]$Update
    )
    $entries = @(Get-ConfiguredPluginEntries -RepositoryRoot $RepositoryRoot)
    $clients = if ($Client -eq 'Both') { @('Claude','Codex') } else { @($Client) }

    foreach ($selectedClient in $clients) {
        $installed = if ($DryRun) { @() } else { @(Get-InstalledPlugins -Client $selectedClient) }
        foreach ($entry in $entries) {
            $marketplace = if ($selectedClient -eq 'Claude') { $entry.claude_marketplace.Trim() } else { $entry.codex_marketplace.Trim() }
            if ($marketplace -eq '-') { $marketplace = '' }
            $plugin = if ($selectedClient -eq 'Claude') { $entry.claude_plugin } else { $entry.codex_plugin }
            if ([string]::IsNullOrWhiteSpace($plugin)) { throw ('Plugin selector missing for {0}: {1}' -f $selectedClient, $entry.name) }

            if ($selectedClient -eq 'Codex' -and $entry.codex_method -ne 'plugin') {
                if ($entry.codex_method -eq 'skill') {
                    $arguments = @('-y','skills','add',$entry.codex_source,'--global','--agent','codex')
                    if ($entry.codex_skill -ne '-') { $arguments = @('-y','skills','add',$entry.codex_source,'--skill',$entry.codex_skill,'--global','--agent','codex') }
                } elseif ($entry.codex_method -eq 'impeccable') {
                    $arguments = @('-y','impeccable','install','-y','--providers=codex','--scope=global')
                } else {
                    throw "Unknown Codex install method '$($entry.codex_method)' for $($entry.name)."
                }
                Invoke-PluginCommand -Command 'npx' -Arguments $arguments -DryRun:$DryRun
                Write-Output "PASS Codex skill ensured: $($entry.name)"
                continue
            }

            $installedItem = if ($selectedClient -eq 'Claude') { $installed | Where-Object { $_.id -eq $plugin } | Select-Object -First 1 } else { $installed | Where-Object { $_.pluginId -eq $plugin } | Select-Object -First 1 }
            if ($Update -and $selectedClient -eq 'Claude' -and $null -ne $installedItem) {
                Invoke-PluginCommand -Command 'claude' -Arguments @('plugin','update',$plugin) -DryRun:$DryRun
                if (-not $installedItem.enabled) {
                    Invoke-PluginCommand -Command 'claude' -Arguments @('plugin','enable',$plugin) -DryRun:$DryRun
                }
                continue
            }
            if (-not $Update -and $null -ne $installedItem) {
                if ($selectedClient -eq 'Claude' -and -not $installedItem.enabled) {
                    Invoke-PluginCommand -Command 'claude' -Arguments @('plugin','enable',$plugin) -DryRun:$DryRun
                }
                Write-Output "PASS $selectedClient plugin already installed: $plugin"
                continue
            }

            if ($selectedClient -eq 'Claude') {
                if (-not [string]::IsNullOrWhiteSpace($marketplace)) {
                    Invoke-PluginCommand -Command 'claude' -Arguments @('plugin','marketplace','add',$marketplace) -DryRun:$DryRun
                }
                Invoke-PluginCommand -Command 'claude' -Arguments @('plugin','install',$plugin,'--scope','user') -DryRun:$DryRun
            } else {
                if (-not [string]::IsNullOrWhiteSpace($marketplace) -and $marketplace -ne 'openai-curated-remote') {
                    $marketplaceName = ($plugin -split '@')[-1]
                    Ensure-CodexMarketplace -Source $marketplace -MarketplaceName $marketplaceName -DryRun:$DryRun
                }
                Invoke-PluginCommand -Command 'codex' -Arguments @('plugin','add',$plugin) -DryRun:$DryRun
            }
            Write-Output "PASS $selectedClient plugin ensured: $plugin"
        }
    }
}
