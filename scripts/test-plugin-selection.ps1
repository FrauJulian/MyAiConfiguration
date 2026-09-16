[CmdletBinding()]
param([switch]$Summary)
$ErrorActionPreference = 'Stop'
function Write-Host { param($Object) if (-not $Summary) { Microsoft.PowerShell.Utility\Write-Host $Object } }
. (Join-Path $PSScriptRoot 'lib/plugins.ps1')

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
$env:AI_CONFIG_VERBOSE = '1'
try { Invoke-PluginCommand -Command Test-PluginOutput -Arguments @('fail') -Summary | ForEach-Object { $diagnostics.Add("$_") } }
catch { $failed = $true }
$env:AI_CONFIG_VERBOSE = $null
if (-not $failed -or $diagnostics -notcontains 'download progress' -or $diagnostics -notcontains 'WARN test warning') { throw 'Plugin failure must retain full diagnostics and fail.' }
$global:LASTEXITCODE = 0
function Get-InstalledPlugins { [pscustomobject]@{ pluginId = 'test@market' } }
$script:commands = @()
function Invoke-PluginCommand { param($Command, $Arguments, [switch]$DryRun, [switch]$Summary) $script:commands += "$Command $($Arguments -join ' ')" }
$entry = [pscustomobject]@{ name = 'Test'; codex_method = 'plugin'; codex_marketplace = '-'; codex_plugin = 'test@market' }
$updated = @(Install-ConfiguredPlugins -RepositoryRoot (Split-Path $PSScriptRoot -Parent) -Client Codex -Update -Summary -Entries @($entry))
if ($commands.Count -ne 1 -or $commands[0] -ne 'codex plugin add test@market' -or $updated[0] -ne 'PLUGINS Codex: 0 ensured, 0 already installed, 1 updated') { throw 'Updating an installed Codex plugin must report one update.' }
function Get-InstalledPlugins { throw 'Empty selection must not query installed plugins.' }
function Invoke-PluginCommand { throw 'Empty selection must not run plugin commands.' }
Install-ConfiguredPlugins -RepositoryRoot (Split-Path $PSScriptRoot -Parent) -Client Both -Entries @()
Uninstall-DeselectedPlugins -Client Both -Entries @()

if ($Summary) { Write-Output 'Tests: PASS | plugin selection' } else { Write-Output 'PASS plugin toggle selection: toggle and confirm' }
exit 0
