function Invoke-PluginCommand {
    param(
        [Parameter(Mandatory=$true)][string]$Command,
        [Parameter(Mandatory=$true)][string[]]$Arguments,
        [switch]$DryRun,
        [switch]$Summary
    )
    $display = "$Command $($Arguments -join ' ')"
    if ($DryRun) { if (-not $Summary) { Write-Output "DRYRUN $display" }; return }
    $resolvedCommand = Get-Command $Command -ErrorAction Stop
    if (-not $Summary) {
        if ($script:PluginNonInteractive) { $null | & $resolvedCommand @Arguments } else { & $resolvedCommand @Arguments }
        if ($LASTEXITCODE -ne 0) { throw "Plugin command failed: $display" }
        return
    }
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = if ($script:PluginNonInteractive) { @($null | & $resolvedCommand @Arguments 2>&1) } else { @(& $resolvedCommand @Arguments 2>&1) }
        $exitCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    if ($exitCode -ne 0 -or -not $Summary -or $env:AI_CONFIG_VERBOSE -eq '1') { $output | Write-Output } else { $output | Where-Object { "$_" -match '(?i)warn|error|fail|deprecat' } }
    if ($exitCode -ne 0) { throw "Plugin command failed: $display" }
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
    param(
        [ValidateSet('Claude','Codex')][string]$Client,
        [string]$HomePath = [Environment]::GetFolderPath('UserProfile')
    )
    $command = Get-Command $Client.ToLowerInvariant() -ErrorAction Stop
    $environment = @{
        HOME = $HomePath
        USERPROFILE = $HomePath
        CODEX_HOME = (Join-Path $HomePath '.codex')
        CLAUDE_CONFIG_DIR = (Join-Path $HomePath '.claude')
    }
    $previousEnvironment = @{}
    foreach ($name in $environment.Keys) { $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
    try {
        foreach ($name in $environment.Keys) { [Environment]::SetEnvironmentVariable($name, $environment[$name], 'Process') }
        $global:LASTEXITCODE = 0
        $output = $null | & $command plugin list --json | Out-String
        if ($LASTEXITCODE -ne 0) { throw "$Client plugin listing failed." }
        $items = $output | ConvertFrom-Json
        if ($Client -eq 'Claude') { return @($items) }
        return @($items.installed)
    } finally {
        foreach ($name in $previousEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], 'Process') }
    }
}

function Read-PluginToggleSelection {
    param(
        [Parameter(Mandatory=$true)][string[]]$Names,
        [Parameter(Mandatory=$true)][bool[]]$Checked
    )
    $state = @($Checked)
    if ([Console]::IsInputRedirected -or $env:CI -eq 'true' -or $env:AI_CONFIG_NO_INTERACTIVE -eq '1') { while($true){ Write-Host 'Select plugins (enter a number to toggle, "done" to confirm):'; for($i=0;$i -lt $Names.Count;$i++){Write-Host ("  {0}) [{1}] {2}" -f ($i+1),$(if($state[$i]){'x'}else{' '}),$Names[$i])}; $answer=Read-Host 'Toggle number or "done"'; if([string]::IsNullOrWhiteSpace($answer)-or $answer -eq 'done'){return $state}; $index=0;if([int]::TryParse($answer,[ref]$index)-and $index -ge 1 -and $index -le $Names.Count){$state[$index-1]= -not $state[$index-1]} } }
    $index=0; while($true){ Clear-Host; Write-Host 'Select plugins'; for($i=0;$i -lt $Names.Count;$i++){ $focus=if($i -eq $index){'>'}else{' '}; $mark=if($state[$i]){'x'}else{' '}; Write-Host "$focus [$mark] $($Names[$i])" }; Write-Host 'Up/Down Navigate   Space Toggle   Enter Confirm'; $key=[Console]::ReadKey($true); if($key.Key -eq 'UpArrow'){$index=($index+$Names.Count-1)%$Names.Count}elseif($key.Key -eq 'DownArrow'){$index=($index+1)%$Names.Count}elseif($key.Key -eq 'Spacebar'){$state[$index]= -not $state[$index]}elseif($key.Key -eq 'Enter'){Clear-Host;return $state} }
}

function Select-ConfiguredPlugins {
    <#
    .SYNOPSIS
        Lets the user toggle each configured plugin on or off. Install mode starts
        with everything checked; update mode starts checked to match what the
        reference client (Claude, or Codex when only Codex is targeted) already
        has installed, so unchecking a currently installed plugin uninstalls it.
    #>
    param(
        [Parameter(Mandatory=$true)][string]$RepositoryRoot,
        [ValidateSet('Codex','Claude','Both')][Parameter(Mandatory=$true)][string]$Client,
        [ValidateSet('Install','Update')][Parameter(Mandatory=$true)][string]$Mode,
        [string]$HomePath = [Environment]::GetFolderPath('UserProfile'),
        [switch]$DryRun
    )
    $entries = @(Get-ConfiguredPluginEntries -RepositoryRoot $RepositoryRoot)
    $toggleable = @($entries)
    $fixed = @($entries | Where-Object { $toggleable -notcontains $_ })
    if ($DryRun -or $toggleable.Count -eq 0) { return @{ Selected = $entries; Deselected = @() } }

    $referenceClient = if ($Client -eq 'Codex') { 'Codex' } else { 'Claude' }
    $installed = if ($Mode -eq 'Update') { @(Get-InstalledPlugins -Client $referenceClient -HomePath $HomePath) } else { @() }
    $idField = if ($referenceClient -eq 'Claude') { 'id' } else { 'pluginId' }
    $checked = @($toggleable | ForEach-Object {
        if ($Mode -eq 'Install') { $true; return }
        if ($_.codex_method -eq 'cli') { return $null -ne (Get-Command $_.codex_source -ErrorAction SilentlyContinue) }
        $selector = if ($referenceClient -eq 'Claude') { $_.claude_plugin } else { $_.codex_plugin }
        if ($referenceClient -eq 'Codex' -and $_.codex_method -eq 'qmd') {
            $null -ne (Get-Command qmd -ErrorAction SilentlyContinue)
        } elseif ($referenceClient -eq 'Codex' -and $_.codex_method -ne 'plugin') {
            (Test-Path -LiteralPath (Join-Path $HomePath ('.agents/skills/' + $_.codex_skill))) -or (Test-Path -LiteralPath (Join-Path $HomePath ('.codex/skills/' + $_.codex_skill)))
        } else { [bool](@($installed | Where-Object { $_.$idField -eq $selector }).Count) }
    })
    $names = @($toggleable | ForEach-Object { $_.name })
    $checked = Read-PluginToggleSelection -Names $names -Checked $checked

    $selected = @()
    $deselected = @()
    for ($i = 0; $i -lt $toggleable.Count; $i++) {
        if ($checked[$i]) { $selected += $toggleable[$i] } else { $deselected += $toggleable[$i] }
    }
    return @{ Selected = ($selected + $fixed); Deselected = $deselected }
}

function Invoke-ManagedExtensions {
    param(
        [Parameter(Mandatory=$true)][string]$RepositoryRoot,
        [Parameter(Mandatory=$true)][string]$Client,
        [string]$HomePath = $HOME,
        [ValidateSet('sync','install','remove')][string]$Action = 'sync',
        [object[]]$Entries,
        [switch]$DryRun,
        [switch]$Update,
        [switch]$Summary
    )
    $arguments = @((Join-Path $PSScriptRoot 'managed-extensions.py'), $Action, '--home', $HomePath, '--manifest', (Join-Path $RepositoryRoot 'adapters/plugins.tsv'), '--client', $Client.ToLowerInvariant())
    if ($DryRun) { $arguments += '--dry-run' }
    if ($Update) { $arguments += '--update' }
    if ($Summary) { $arguments += '--summary' }
    if ($PSBoundParameters.ContainsKey('Entries')) { $arguments += '--selected'; $arguments += @($Entries | ForEach-Object { $_.name }) }
    & python @arguments
    if ($LASTEXITCODE -ne 0) { throw 'Managed extension reconciliation failed.' }
}

function Sync-ConfiguredPlugins {
    param(
        [Parameter(Mandatory=$true)][string]$RepositoryRoot,
        [ValidateSet('Codex','Claude','Both')][Parameter(Mandatory=$true)][string]$Client,
        [string]$HomePath = $HOME,
        [object[]]$Entries,
        [switch]$DryRun,
        [switch]$Update,
        [switch]$Summary
    )
    Invoke-ManagedExtensions @PSBoundParameters -Action sync
}

function Install-ConfiguredPlugins {
    param(
        [Parameter(Mandatory=$true)][string]$RepositoryRoot,
        [ValidateSet('Codex','Claude','Both')][Parameter(Mandatory=$true)][string]$Client,
        [string]$HomePath = $HOME,
        [object[]]$Entries,
        [switch]$DryRun,
        [switch]$Update,
        [switch]$Summary
    )
    if ($PSBoundParameters.ContainsKey('Entries') -and $Entries.Count -eq 0) { return }
    Invoke-ManagedExtensions @PSBoundParameters -Action install
}

function Uninstall-DeselectedPlugins {
    param(
        [Parameter(Mandatory=$true)][AllowEmptyCollection()][object[]]$Entries,
        [ValidateSet('Codex','Claude','Both')][Parameter(Mandatory=$true)][string]$Client,
        [string]$RepositoryRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
        [string]$HomePath = $HOME,
        [switch]$DryRun,
        [switch]$Summary
    )
    if ($Entries.Count -eq 0) { return }
    Invoke-ManagedExtensions -RepositoryRoot $RepositoryRoot -Client $Client -HomePath $HomePath -Entries $Entries -Action remove -DryRun:$DryRun -Summary:$Summary
}
