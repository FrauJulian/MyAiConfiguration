[CmdletBinding()]
param([switch]$Summary)
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
function Write-Host { param($Object) if (-not $Summary) { Microsoft.PowerShell.Utility\Write-Host $Object } }
. (Join-Path $root 'scripts/lib/plugins.ps1')

$script:answers = [System.Collections.Generic.Queue[string]]::new()
$script:answers.Enqueue('1')
$script:answers.Enqueue('2')
$script:answers.Enqueue('done')
function Read-Host { param($Prompt) $answers.Dequeue() }

$result = Read-PluginToggleSelection -Names @('A','B','C') -Checked @($true, $false, $true)
if ($result[0] -ne $false) { throw 'Toggling checked entry 1 must uncheck it.' }
if ($result[1] -ne $true) { throw 'Toggling unchecked entry 2 must check it.' }
if ($result[2] -ne $true) { throw 'Entry 3 was never toggled and must stay unchanged.' }

$script:answers.Enqueue('')
$confirmed = @(Read-PluginToggleSelection -Names @('A') -Checked @($true))
if ($confirmed.Count -ne 1 -or -not $confirmed[0]) { throw 'Enter must confirm without changing the selection.' }
function Test-PluginOutput {
    param([string]$Mode)
    Write-Output 'download progress'
    Write-Output 'WARN test warning'
    $global:LASTEXITCODE = if ($Mode -eq 'fail') { 7 } else { 0 }
}
$compact = @(Invoke-PluginCommand -Command Test-PluginOutput -Arguments @('success') -Summary)
if ($compact.Count -ne 1 -or $compact[0] -ne 'WARN test warning') { throw 'Plugin summary must retain warnings and suppress progress.' }
$detailed = @(Invoke-PluginCommand -Command Test-PluginOutput -Arguments @('success'))
if ($detailed.Count -ne 2 -or $detailed[0] -ne 'download progress') { throw 'Detailed output must retain progress.' }
$diagnostics = [System.Collections.Generic.List[string]]::new()
$failed = $false
$env:AI_CONFIG_VERBOSE = $null
try { Invoke-PluginCommand -Command Test-PluginOutput -Arguments @('fail') -Summary | ForEach-Object { $diagnostics.Add("$_") } }
catch { $failed = $true }
$env:AI_CONFIG_VERBOSE = $null
if (-not $failed -or $diagnostics -notcontains 'download progress' -or $diagnostics -notcontains 'WARN test warning') { throw 'Plugin failure must retain full diagnostics and fail.' }
$global:LASTEXITCODE = 0
function codex { $script:observedCodexHome = $env:CODEX_HOME; $script:observedProfile = $env:USERPROFILE; '{"installed":[{"pluginId":"ponytail@ponytail"},{"pluginId":"i-have-adhd@i-have-adhd"},{"pluginId":"superpowers@openai-curated-remote"},{"pluginId":"context7@context7-marketplace"},{"pluginId":"caveman@thinkhome-caveman"}],"available":[]}' }
$previousCodexHome = $env:CODEX_HOME
$previousProfile = $env:USERPROFILE
$null = Get-InstalledPlugins -Client Codex -HomePath 'C:/temporary profile'
if ($observedCodexHome -ne (Join-Path 'C:/temporary profile' '.codex') -or $observedProfile -ne 'C:/temporary profile') { throw 'Plugin inspection must use the requested user home.' }
if ($env:CODEX_HOME -ne $previousCodexHome -or $env:USERPROFILE -ne $previousProfile) { throw 'Plugin inspection must restore the process environment.' }
$script:answers.Enqueue('done')
$selection = Select-ConfiguredPlugins -RepositoryRoot (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Client Codex -Mode Update
if (@($selection.Selected | Where-Object { $_.codex_method -eq 'plugin' }).Count -ne 5) { throw 'All installed Codex plugins must start checked when updating.' }
$script:answers.Enqueue('4')
$script:answers.Enqueue('done')
$selection = Select-ConfiguredPlugins -RepositoryRoot (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Client Codex -Mode Update
if (@($selection.Deselected | Where-Object { $_.name -eq 'Context7' }).Count -ne 1) { throw 'Only the explicitly unchecked installed plugin must be deselected.' }
$script:managedArguments = @()
function python { $script:managedArguments = @($args); $global:LASTEXITCODE = 0 }
$entry = [pscustomobject]@{ name = 'Test'; codex_method = 'plugin'; codex_marketplace = '-'; codex_plugin = 'test@market' }
Sync-ConfiguredPlugins -RepositoryRoot (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Client Codex -HomePath 'C:/temporary home' -Update -Summary -Entries @($entry)
if ($managedArguments -notcontains 'sync' -or $managedArguments -notcontains '--update' -or $managedArguments -notcontains 'Test' -or $managedArguments -notcontains 'C:/temporary home') { throw 'Managed reconciliation must receive selection, home, and update mode.' }
Sync-ConfiguredPlugins -RepositoryRoot (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Client Codex -Entries @()
if ($managedArguments[-1] -ne '--selected') { throw 'Empty selection must reach reconciliation for managed cleanup.' }
function Get-InstalledPlugins { throw 'Empty selection must not query installed plugins.' }
function Invoke-PluginCommand { throw 'Empty selection must not run plugin commands.' }
Install-ConfiguredPlugins -RepositoryRoot (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Client Both -Entries @()
Uninstall-DeselectedPlugins -Client Both -Entries @()

if ($Summary) { Write-Output 'Tests: PASS | plugin selection' } else { Write-Output 'PASS plugin toggle selection: toggle and confirm' }
exit 0
