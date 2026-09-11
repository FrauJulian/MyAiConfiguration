[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$shared = Join-Path $root 'shared'
$output = Join-Path $root 'generated'
$pluginManifest = Join-Path $root 'adapters/plugins.tsv'
if (-not (Test-Path -LiteralPath $pluginManifest)) { throw "Missing plugin manifest: $pluginManifest" }
$pluginEntries = @(Import-Csv -LiteralPath $pluginManifest -Delimiter ([char]9))
if ($pluginEntries.Count -ne 4) { throw 'Plugin manifest must define exactly four plugins.' }
foreach ($pluginEntry in $pluginEntries) {
    foreach ($field in @('claude_plugin','codex_plugin')) {
        if ([string]::IsNullOrWhiteSpace($pluginEntry.$field)) { throw "Missing $field for plugin $($pluginEntry.name)." }
    }
}
Remove-Item $output -Recurse -Force -ErrorAction SilentlyContinue
New-Item $output -ItemType Directory -Force | Out-Null
function Copy-Directory($source, $destination) {
    New-Item $destination -ItemType Directory -Force | Out-Null
    Get-ChildItem $source -File -Recurse | ForEach-Object {
        $relative = $_.FullName.Substring($source.Length).TrimStart([char[]]@('\','/'))
        $target = Join-Path $destination $relative
        New-Item (Split-Path $target -Parent) -ItemType Directory -Force | Out-Null
        Copy-Item $_.FullName $target -Force
    }
}
function Read-Field($path, $name) {
    $line = Get-Content $path | Where-Object { $_ -match ('^' + [regex]::Escape($name) + ':\s*(.*)$') } | Select-Object -First 1
    if (-not $line) { throw "Missing $name in $path" }
    return ([regex]::Match($line, '^' + [regex]::Escape($name) + ':\s*(.*)$')).Groups[1].Value.Trim()
}
function Quote-Toml($value) {
    return ('"' + $value.Replace('\','\\').Replace('"','\"').Replace("`r",'').Replace("`n",'\n') + '"')
}
& (Join-Path $root 'shared/hooks/scripts/Test-SessionConfig.ps1') -RepositoryRoot $root
foreach ($platform in @('windows','linux')) {
Copy-Directory (Join-Path $shared 'skills') (Join-Path $output "codex-$platform/skills")
Copy-Directory (Join-Path $shared 'skills') (Join-Path $output "claude-$platform/skills")
Copy-Directory (Join-Path $shared 'rules') (Join-Path $output "codex-$platform/rules")
Copy-Directory (Join-Path $shared 'rules') (Join-Path $output "claude-$platform/rules")
New-Item (Join-Path $output "codex-$platform") -ItemType Directory -Force | Out-Null
New-Item (Join-Path $output "claude-$platform") -ItemType Directory -Force | Out-Null
Copy-Directory (Join-Path $shared 'hooks') (Join-Path $output "codex-$platform/hooks")
Copy-Directory (Join-Path $shared 'hooks') (Join-Path $output "claude-$platform/hooks")
Copy-Directory (Join-Path $shared 'statusline') (Join-Path $output "claude-$platform/statusline")
Copy-Item (Join-Path $shared 'global-instructions.md') (Join-Path $output "codex-$platform/AGENTS.md") -Force
Copy-Item (Join-Path $shared 'global-instructions.md') (Join-Path $output "claude-$platform/CLAUDE.md") -Force
Copy-Item (Join-Path $root 'adapters/codex/config/config.toml') (Join-Path $output "codex-$platform/config.toml") -Force
Copy-Item (Join-Path $root 'adapters/claude/config/settings.json') (Join-Path $output "claude-$platform/settings.json") -Force
foreach ($client in @('codex','claude')) {
    $agentsOutput = Join-Path $output "$client-$platform/agents"
    New-Item $agentsOutput -ItemType Directory -Force | Out-Null
    Get-ChildItem (Join-Path $shared 'agents') -Directory | Sort-Object Name | ForEach-Object {
        $metadata = Join-Path $_.FullName 'agent.yml'
        $name = Read-Field $metadata 'name'
        $description = Read-Field $metadata 'description'
        $instructions = Get-Content (Join-Path $_.FullName 'instructions.md') -Raw
        if ($client -eq 'codex') {
            Set-Content (Join-Path $agentsOutput "$name.toml") "name = $(Quote-Toml $name)`r`ndescription = $(Quote-Toml $description)`r`ndeveloper_instructions = $(Quote-Toml $instructions)" -Encoding UTF8
        } else {
            Set-Content (Join-Path $agentsOutput "$name.md") "---`r`nname: $name`r`ndescription: $description`r`n---`r`n`r`n$instructions" -Encoding UTF8
        }
    }
}

foreach ($client in @('codex','claude')) {
    $file = if ($client -eq 'codex') { 'config.toml' } else { 'settings.json' }
    $path = Join-Path $output "$client-$platform/$file"
    $command = if ($platform -eq 'windows') { 'powershell -NoProfile -ExecutionPolicy Bypass -File' } else { 'bash' }
    $script = if ($platform -eq 'windows') { 'flashbang.ps1' } else { 'flashbang.sh' }
    $statusLineScript = if ($platform -eq 'windows') { 'statusline.ps1' } else { 'statusline.sh' }
    $content = Get-Content -LiteralPath $path -Raw
    $content = $content.Replace('__HOOK_COMMAND__', $command).Replace('__WINDOWS_HOOK_COMMAND__', $command).Replace('__HOOK_SCRIPT__', $script).Replace('__WINDOWS_HOOK_SCRIPT__', $script).Replace('__STATUSLINE_COMMAND__', $command).Replace('__STATUSLINE_SCRIPT__', $statusLineScript)
    Set-Content -LiteralPath $path -Value $content -Encoding UTF8
}
}
Write-Output 'PASS build: codex-windows, claude-windows, codex-linux, claude-linux'

