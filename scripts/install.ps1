[CmdletBinding()]
param([switch]$DryRun)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'lib/plugins.ps1')
$buildScript = Join-Path $PSScriptRoot 'build.ps1'
& $buildScript
if (-not $?) { throw 'Build failed. Installation was not started.' }
$generated = Join-Path $root 'generated'
if (-not (Test-Path $generated)) { throw 'Generated output is missing after a successful build.' }
Write-Output 'Select target platform:'
Write-Output '1) Windows'
Write-Output '2) Linux'
do { $platformSelection = Read-Host 'Selection [1-2]' } while ($platformSelection -notin @('1','2'))
$platform = @{'1'='windows'; '2'='linux'}[$platformSelection]
Write-Output 'Select installation target:'
Write-Output '1) Codex'
Write-Output '2) Claude'
Write-Output '3) Both'
do { $selection = Read-Host 'Selection [1-3]' } while ($selection -notin @('1','2','3'))
$Client = @{'1'='Codex'; '2'='Claude'; '3'='Both'}[$selection]
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$homePath = [Environment]::GetFolderPath('UserProfile')
$shellCommand = 'pwsh -NoProfile -ExecutionPolicy Bypass -File'
$windowsShellCommand = 'powershell -NoProfile -ExecutionPolicy Bypass -File'
if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { $shellCommand = $windowsShellCommand }
$targets = @()
if ($Client -in @('Codex','Both')) { $targets += @{ Source=(Join-Path $generated "codex-$platform"); Destination=(Join-Path $homePath '.codex') } }
if ($Client -in @('Codex','Both')) { $targets += @{ Source=(Join-Path $generated "codex-$platform/skills"); Destination=(Join-Path $homePath '.agents/skills') } }
if ($Client -in @('Claude','Both')) { $targets += @{ Source=(Join-Path $generated "claude-$platform"); Destination=(Join-Path $homePath '.claude') } }
foreach ($item in $targets) {
    $backupRoot = Join-Path $item.Destination 'backups'
    Get-ChildItem $item.Source -File -Recurse | ForEach-Object {
        $relative = $_.FullName.Substring($item.Source.Length).TrimStart([char[]]@('\','/'))
        $target = Join-Path $item.Destination $relative
        if ($DryRun) { Write-Output "DRYRUN $($_.FullName) -> $target"; return }
        if (Test-Path $target) {
            $backup = Join-Path $backupRoot $relative
            New-Item (Split-Path $backup -Parent) -ItemType Directory -Force | Out-Null
            Copy-Item $target "$backup.$stamp" -Force
        }
        New-Item (Split-Path $target -Parent) -ItemType Directory -Force | Out-Null
        $content = Get-Content $_.FullName -Raw
        if ($content.Contains('__AI_CONFIG_ROOT__') -or $content.Contains('__HOOK_COMMAND__') -or $content.Contains('__WINDOWS_HOOK_COMMAND__')) {
            $replacement = $item.Destination.Replace('\','/')
            $content = $content.Replace('__AI_CONFIG_ROOT__', $replacement)
            $content = $content.Replace('__HOOK_COMMAND__', $shellCommand)
            $content = $content.Replace('__WINDOWS_HOOK_COMMAND__', $windowsShellCommand)
            $content = $content.Replace('__HOOK_SCRIPT__', 'flashbang.ps1')
            $content = $content.Replace('__WINDOWS_HOOK_SCRIPT__', 'flashbang.ps1')
            [System.IO.File]::WriteAllText($target, $content, (New-Object System.Text.UTF8Encoding($false)))
        }
        else { Copy-Item $_.FullName $target -Force }
        Write-Output "INSTALL $target"
    }
}
Install-ConfiguredPlugins -RepositoryRoot $root -Client $Client -DryRun:$DryRun -Update
Write-Output ($(if ($DryRun) { 'PASS install dry-run' } else { 'PASS install' }))
