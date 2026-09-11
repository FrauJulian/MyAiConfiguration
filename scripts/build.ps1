[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$shared = Join-Path $root 'shared'
$output = Join-Path $root 'generated'
$pluginManifest = Join-Path $root 'adapters/plugins.tsv'
$ruleSkillManifest = Join-Path $root 'adapters/claude/rule-skills.tsv'

if (-not (Test-Path -LiteralPath $pluginManifest)) { throw "Missing plugin manifest: $pluginManifest" }
$pluginEntries = @(Import-Csv -LiteralPath $pluginManifest -Delimiter ([char]9))
if ($pluginEntries.Count -eq 0) { throw 'Plugin manifest must define at least one plugin.' }
$pluginNames = @()
foreach ($pluginEntry in $pluginEntries) {
    foreach ($field in @('name','claude_plugin','codex_plugin')) {
        if ([string]::IsNullOrWhiteSpace($pluginEntry.$field)) { throw "Missing $field for plugin $($pluginEntry.name)." }
    }
    if ($pluginNames -contains $pluginEntry.name) { throw "Duplicate plugin name in manifest: $($pluginEntry.name)" }
    $pluginNames += $pluginEntry.name
}

if (-not (Test-Path -LiteralPath $ruleSkillManifest)) { throw "Missing rule-skill manifest: $ruleSkillManifest" }
$ruleSkillEntries = @(Import-Csv -LiteralPath $ruleSkillManifest -Delimiter ([char]9) | Sort-Object skill_name)
if ($ruleSkillEntries.Count -eq 0) { throw 'Rule-skill manifest must define at least one entry.' }
$ruleSkillNames = @()
foreach ($entry in $ruleSkillEntries) {
    foreach ($field in @('rule_file','skill_name','trigger')) {
        if ([string]::IsNullOrWhiteSpace($entry.$field)) { throw "Missing $field in rule-skill manifest row for $($entry.rule_file)." }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $shared "rules/$($entry.rule_file)"))) { throw "Rule-skill manifest references a missing rule file: $($entry.rule_file)" }
    if ($ruleSkillNames -contains $entry.skill_name) { throw "Duplicate rule-skill name in manifest: $($entry.skill_name)" }
    $ruleSkillNames += $entry.skill_name
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

$sourceAgentDirs = @(Get-ChildItem (Join-Path $shared 'agents') -Directory | Sort-Object Name)
if ($sourceAgentDirs.Count -eq 0) { throw 'No agents found under shared/agents.' }
$agentNames = @()
foreach ($agentDir in $sourceAgentDirs) {
    $name = Read-Field (Join-Path $agentDir.FullName 'agent.yml') 'name'
    if ($agentNames -contains $name) { throw "Duplicate agent name: $name" }
    $agentNames += $name
}

# Codex keeps the original rule-loading text unchanged: every rule ships as a plain
# file and AGENTS.md tells Codex to load the matching one by path.
$codexRuleLoading = @'
Always load and apply `rules/general.md` before starting any task.

When programming, always load and apply `rules/security.md`. This includes implementing, modifying, debugging, reviewing, testing, and configuring software, scripts, hooks, infrastructure, and integrations.

Detect the languages, frameworks, tools, and change areas from the repository and the requested work. Load every applicable rule file before editing. Load all matching files when multiple technologies apply.

Load rule files when their subject applies:

- rules/angular.md for Angular work.
- rules/typescript.md for TypeScript work.
- rules/csharp.md for C# or .NET work.
- rules/wpf.md for WPF work.
- rules/ui-ux.md for UI or UX decisions.
- rules/microsoft.md for Microsoft 365, Azure DevOps, or Teams work.
- rules/git.md for Git operations.
- rules/refactoring.md for refactoring work.
- rules/definition-of-done.md when validating completion.
- rules/decision-rule.md when requirements, behavior, or technical choices need to be evaluated.
'@

foreach ($platform in @('windows','linux')) {
    New-Item (Join-Path $output "codex-$platform") -ItemType Directory -Force | Out-Null
    New-Item (Join-Path $output "claude-$platform") -ItemType Directory -Force | Out-Null
    Copy-Directory (Join-Path $shared 'skills') (Join-Path $output "codex-$platform/skills")
    Copy-Directory (Join-Path $shared 'skills') (Join-Path $output "claude-$platform/skills")
    Copy-Directory (Join-Path $shared 'rules') (Join-Path $output "codex-$platform/rules")
    Copy-Directory (Join-Path $shared 'hooks') (Join-Path $output "codex-$platform/hooks")
    Copy-Directory (Join-Path $shared 'hooks') (Join-Path $output "claude-$platform/hooks")
    Copy-Directory (Join-Path $shared 'statusline') (Join-Path $output "claude-$platform/statusline")

    # Claude: general.md stays a plain, always-applied rule file. Every technology- or
    # situation-specific rule becomes a skill instead, so only its name and description
    # sit permanently in context; the full text loads only when the skill is invoked.
    $claudeRulesDir = Join-Path $output "claude-$platform/rules"
    New-Item $claudeRulesDir -ItemType Directory -Force | Out-Null
    Copy-Item (Join-Path $shared 'rules/general.md') (Join-Path $claudeRulesDir 'general.md') -Force

    $claudeRuleSkillLines = @()
    foreach ($entry in $ruleSkillEntries) {
        $skillDir = Join-Path $output "claude-$platform/skills/rules/$($entry.skill_name)"
        New-Item $skillDir -ItemType Directory -Force | Out-Null
        $ruleContent = Get-Content (Join-Path $shared "rules/$($entry.rule_file)") -Raw
        $skillBody = "---`r`nname: $($entry.skill_name)`r`ndescription: Use for $($entry.trigger).`r`n---`r`n`r`n$ruleContent"
        Set-Content (Join-Path $skillDir 'SKILL.md') $skillBody -Encoding UTF8
        $claudeRuleSkillLines += "- $($entry.skill_name) for $($entry.trigger)."
    }
    $claudeRuleLoading = "Always apply ``rules/general.md`` before starting any task, embedded below.`r`n`r`nDetect the languages, frameworks, tools, and change areas from the repository and the requested work. Invoke every matching rule skill before editing. Invoke all matching rule skills when multiple technologies apply.`r`n`r`nInvoke rule skills when their subject applies:`r`n`r`n" + ($claudeRuleSkillLines -join "`r`n")

    $sharedTemplate = Get-Content (Join-Path $shared 'global-instructions.md') -Raw
    Set-Content (Join-Path $output "codex-$platform/AGENTS.md") ($sharedTemplate.Replace('__RULE_LOADING__', $codexRuleLoading)) -Encoding UTF8

    $generalContent = Get-Content (Join-Path $shared 'rules/general.md') -Raw
    $claudeContent = $sharedTemplate.Replace('__RULE_LOADING__', $claudeRuleLoading)
    $claudeContent = $claudeContent.TrimEnd() + "`r`n`r`n---`r`n`r`n$generalContent"
    Set-Content (Join-Path $output "claude-$platform/CLAUDE.md") $claudeContent -Encoding UTF8

    Copy-Item (Join-Path $root 'adapters/codex/config/config.toml') (Join-Path $output "codex-$platform/config.toml") -Force
    Copy-Item (Join-Path $root 'adapters/claude/config/settings.json') (Join-Path $output "claude-$platform/settings.json") -Force

    foreach ($client in @('codex','claude')) {
        $agentsOutput = Join-Path $output "$client-$platform/agents"
        New-Item $agentsOutput -ItemType Directory -Force | Out-Null
        foreach ($agentDir in $sourceAgentDirs) {
            $metadata = Join-Path $agentDir.FullName 'agent.yml'
            $name = Read-Field $metadata 'name'
            $description = Read-Field $metadata 'description'
            $instructions = Get-Content (Join-Path $agentDir.FullName 'instructions.md') -Raw
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

    $tomlPath = Join-Path $output "codex-$platform/config.toml"
    $tomlContent = Get-Content -LiteralPath $tomlPath -Raw
    if (([regex]::Matches($tomlContent, '(?<!\\)"')).Count % 2 -ne 0) { throw "Generated Codex config.toml has unbalanced quotes: $tomlPath" }
    if (([regex]::Matches($tomlContent, '\[')).Count -ne ([regex]::Matches($tomlContent, '\]')).Count) { throw "Generated Codex config.toml has unbalanced brackets: $tomlPath" }

    $settingsPath = Join-Path $output "claude-$platform/settings.json"
    try { Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json | Out-Null }
    catch { throw "Generated Claude settings.json is not valid JSON: $settingsPath" }
}

$leftoverPlaceholders = @(Get-ChildItem $output -File -Recurse | ForEach-Object {
    # __AI_CONFIG_ROOT__ is resolved at install time, once the destination is known; it is
    # expected to remain in generated output. -cmatch keeps this case-sensitive so Python
    # dunder names (__main__, __name__) in flashbang.sh are not mistaken for placeholders.
    $content = (Get-Content -LiteralPath $_.FullName -Raw) -replace '__AI_CONFIG_ROOT__', ''
    if ($content -cmatch '__[A-Z0-9_]+__') { $_.FullName }
})
if ($leftoverPlaceholders.Count) { throw "Unresolved template placeholders in: $($leftoverPlaceholders -join ', ')" }

Write-Output 'PASS build: codex-windows, claude-windows, codex-linux, claude-linux'
exit 0
