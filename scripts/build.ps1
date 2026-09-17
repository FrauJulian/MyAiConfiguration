[CmdletBinding()]
param([switch]$Summary)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$shared = Join-Path $root 'shared'
$output = Join-Path $root 'generated'
$pluginManifest = Join-Path $root 'adapters/plugins.tsv'
$ruleSkillManifest = Join-Path $root 'adapters/rule-skills.tsv'
$capabilityManifest = Join-Path $root 'adapters/claude/capabilities.tsv'

if (-not (Test-Path -LiteralPath $pluginManifest)) { throw "Missing plugin manifest: $pluginManifest" }
$pluginEntries = @(Import-Csv -LiteralPath $pluginManifest -Delimiter ([char]9))
if ($pluginEntries.Count -eq 0) { throw 'Plugin manifest must define at least one plugin.' }
$pluginNames = @()
foreach ($pluginEntry in $pluginEntries) {
    foreach ($field in @('name','claude_plugin','codex_method')) {
        if ([string]::IsNullOrWhiteSpace($pluginEntry.$field)) { throw "Missing $field for plugin $($pluginEntry.name)." }
    }
    if ($pluginNames -contains $pluginEntry.name) { throw "Duplicate plugin name in manifest: $($pluginEntry.name)" }
    $pluginNames += $pluginEntry.name
}

if (-not (Test-Path -LiteralPath $ruleSkillManifest)) { throw "Missing rule-skill manifest: $ruleSkillManifest" }
if (-not (Test-Path -LiteralPath $capabilityManifest)) { throw "Missing capability manifest: $capabilityManifest" }
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
$agentTools = @{}
foreach ($entry in @(Import-Csv -LiteralPath $capabilityManifest -Delimiter ([char]9))) {
    if ([string]::IsNullOrWhiteSpace($entry.role) -or [string]::IsNullOrWhiteSpace($entry.tools)) { throw 'Invalid capability manifest row.' }
    $agentTools[$entry.role] = $entry.tools
}
$codexRuleLoadingLines = @()
foreach ($entry in $ruleSkillEntries) {
    $rulePath = $entry.rule_file
    if (Test-Path -LiteralPath (Join-Path $shared "rules/$($entry.rule_file)") -PathType Container) { $rulePath = "$($entry.rule_file)/index.md" }
    $codexRuleLoadingLines += "- rules/$rulePath for $($entry.trigger)."
}
$codexRuleLoadingList = $codexRuleLoadingLines -join "`r`n"

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
function Test-CodexSchema($configPath) {
    if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
        if ($env:REQUIRE_CODEX_SCHEMA -eq 'true') { throw 'Codex CLI is required for schema validation.' }
        Write-Warning 'Codex CLI unavailable; skipped Codex schema validation.'
        return
    }
    $tempHome = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-schema-" + [Guid]::NewGuid())
    $previousCodexHome = $env:CODEX_HOME
    try {
        New-Item $tempHome -ItemType Directory -Force | Out-Null
        Copy-Item $configPath (Join-Path $tempHome 'config.toml') -Force
        $env:CODEX_HOME = $tempHome
        $previousErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $schemaOutput = @(& codex --strict-config --help 2>&1)
            $schemaExitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
        if ($schemaExitCode -ne 0) { throw "Codex schema validation failed: $configPath`n$($schemaOutput -join [Environment]::NewLine)" }
    } finally {
        $env:CODEX_HOME = $previousCodexHome
        Remove-Item $tempHome -Recurse -Force -ErrorAction SilentlyContinue
    }
}

& (Join-Path $root 'shared/hooks/scripts/Test-SessionConfig.ps1') -RepositoryRoot $root | Where-Object { -not $Summary -or $_ -ne 'PASS session configuration' }

$sourceAgentDirs = @(Get-ChildItem (Join-Path $shared 'agents') -Directory | Sort-Object Name)
if ($sourceAgentDirs.Count -eq 0) { throw 'No agents found under shared/agents.' }
$agentNames = @()
foreach ($agentDir in $sourceAgentDirs) {
    $name = Read-Field (Join-Path $agentDir.FullName 'agent.yml') 'name'
    if ($agentNames -contains $name) { throw "Duplicate agent name: $name" }
    $agentNames += $name
}

# Codex: general.md is embedded directly into AGENTS.md, the same way Claude embeds
# it into CLAUDE.md, instead of only being referenced by path — guaranteed present
# either way, and safe even if a subagent's AGENTS.md inheritance is not guaranteed.
$codexRuleLoading = @'
General rules are embedded below.

When programming, always load and apply `rules/security.md`. This includes implementing, modifying, debugging, reviewing, testing, and configuring software, scripts, hooks, infrastructure, and integrations.

Detect the languages, frameworks, tools, and change areas from the repository and the requested work. Load every applicable rule file before editing. Load all matching files when multiple technologies apply.

Load rule files when their subject applies:

__CODEX_RULE_LOADING__
'@
$codexRuleLoading = $codexRuleLoading.Replace('__CODEX_RULE_LOADING__', $codexRuleLoadingList)

foreach ($shell in @('powershell','bash')) {
    New-Item (Join-Path $output "codex-$shell") -ItemType Directory -Force | Out-Null
    New-Item (Join-Path $output "claude-$shell") -ItemType Directory -Force | Out-Null
    Copy-Directory (Join-Path $shared 'skills') (Join-Path $output "codex-$shell/skills")
    Copy-Directory (Join-Path $shared 'skills') (Join-Path $output "claude-$shell/skills")
    Copy-Directory (Join-Path $shared 'rules') (Join-Path $output "codex-$shell/rules")
    Copy-Directory (Join-Path $shared 'hooks') (Join-Path $output "codex-$shell/hooks")
    Copy-Directory (Join-Path $shared 'hooks') (Join-Path $output "claude-$shell/hooks")
    Copy-Directory (Join-Path $shared 'statusline') (Join-Path $output "claude-$shell/statusline")

    $claudeRulesDir = Join-Path $output "claude-$shell/rules"
    New-Item $claudeRulesDir -ItemType Directory -Force | Out-Null

    $claudeRuleSkillLines = @()
    foreach ($entry in $ruleSkillEntries) {
        $ruleSourcePath = Join-Path $shared "rules/$($entry.rule_file)"
        $isDirectory = Test-Path -LiteralPath $ruleSourcePath -PathType Container
        $ruleBodyPath = if ($isDirectory) { Join-Path $ruleSourcePath 'index.md' } else { $ruleSourcePath }
        $skillDir = Join-Path $output "claude-$shell/skills/rules/$($entry.skill_name)"
        New-Item $skillDir -ItemType Directory -Force | Out-Null
        $ruleContent = Get-Content $ruleBodyPath -Raw
        $skillBody = "---`r`nname: $($entry.skill_name)`r`ndescription: $(Quote-Toml "Use for $($entry.trigger).")`r`n---`r`n`r`n$ruleContent"
        Set-Content (Join-Path $skillDir 'SKILL.md') $skillBody -Encoding UTF8
        if ($isDirectory) {
            $referencesSource = Join-Path $ruleSourcePath 'references'
            if (Test-Path -LiteralPath $referencesSource) { Copy-Directory $referencesSource (Join-Path $skillDir 'references') }
        }
        $claudeRuleSkillLines += "- $($entry.skill_name) for $($entry.trigger)."
    }
    $claudeRuleLoading = "General rules are embedded below.`r`n`r`nDetect the languages, frameworks, tools, and change areas from the repository and the requested work. Invoke every matching rule skill before editing. Invoke all matching rule skills when multiple technologies apply.`r`n`r`nInvoke rule skills when their subject applies:`r`n`r`n" + ($claudeRuleSkillLines -join "`r`n")

    $sharedTemplate = Get-Content (Join-Path $shared 'global-instructions.md') -Raw
    $generalContent = Get-Content (Join-Path $shared 'rules/general.md') -Raw

    $agentsContent = $sharedTemplate.Replace('__RULE_LOADING__', $codexRuleLoading)
    $agentsContent = $agentsContent.TrimEnd() + "`r`n`r`n---`r`n`r`n$generalContent"
    Set-Content (Join-Path $output "codex-$shell/AGENTS.md") $agentsContent -Encoding UTF8

    $claudeContent = $sharedTemplate.Replace('__RULE_LOADING__', $claudeRuleLoading)
    $claudeContent = $claudeContent.TrimEnd() + "`r`n`r`n---`r`n`r`n$generalContent"
    Set-Content (Join-Path $output "claude-$shell/CLAUDE.md") $claudeContent -Encoding UTF8

    Copy-Item (Join-Path $root 'adapters/codex/config/config.toml') (Join-Path $output "codex-$shell/config.toml") -Force
    Copy-Item (Join-Path $root 'adapters/claude/config/settings.json') (Join-Path $output "claude-$shell/settings.json") -Force

    foreach ($client in @('codex','claude')) {
        $agentsOutput = Join-Path $output "$client-$shell/agents"
        New-Item $agentsOutput -ItemType Directory -Force | Out-Null
        foreach ($agentDir in $sourceAgentDirs) {
            $metadata = Join-Path $agentDir.FullName 'agent.yml'
            $name = Read-Field $metadata 'name'
            $description = Read-Field $metadata 'description'
            $loader = (Get-Content (Join-Path $root "adapters/$client/orchestration-loader.txt") -Raw -Encoding UTF8).Trim()
            $instructions = $loader + "`n`n" + (Get-Content (Join-Path $agentDir.FullName 'instructions.md') -Raw -Encoding UTF8)
            if ($client -eq 'codex') {
                Set-Content (Join-Path $agentsOutput "$name.toml") "name = $(Quote-Toml $name)`r`ndescription = $(Quote-Toml $description)`r`ndeveloper_instructions = $(Quote-Toml $instructions)" -Encoding UTF8
            } else {
                $tools = $agentTools[$name]
                $frontmatter = "---`r`nname: $name`r`ndescription: $description`r`n"
                if ($tools) { $frontmatter += "tools: $tools`r`n" }
                Set-Content (Join-Path $agentsOutput "$name.md") ($frontmatter + "---`r`n`r`n$instructions") -Encoding UTF8
            }
        }
    }

    foreach ($client in @('codex','claude')) {
        $file = if ($client -eq 'codex') { 'config.toml' } else { 'settings.json' }
        $path = Join-Path $output "$client-$shell/$file"
        $command = if ($shell -eq 'powershell') { '__POWERSHELL_COMMAND__' } else { 'bash' }
        $script = if ($shell -eq 'powershell') { 'flashbang.ps1' } else { 'flashbang.sh' }
        $statusLineScript = if ($shell -eq 'powershell') { 'statusline.ps1' } else { 'statusline.sh' }
        $content = Get-Content -LiteralPath $path -Raw
        $compactScript = if ($shell -eq 'powershell') { 'Record-Compact.ps1' } else { 'record-compact.sh' }
        $pointerScript = if ($shell -eq 'powershell') { 'Show-SessionStatePointer.ps1' } else { 'show-session-state-pointer.sh' }
        $content = $content.Replace('__HOOK_COMMAND__', $command).Replace('__POWERSHELL_HOOK_COMMAND__', $command).Replace('__HOOK_SCRIPT__', $script).Replace('__POWERSHELL_HOOK_SCRIPT__', $script).Replace('__COMPACT_SCRIPT__', $compactScript).Replace('__SESSION_POINTER_SCRIPT__', $pointerScript).Replace('__STATUSLINE_COMMAND__', $command).Replace('__STATUSLINE_SCRIPT__', $statusLineScript)
        Set-Content -LiteralPath $path -Value $content -Encoding UTF8
    }

    $tomlPath = Join-Path $output "codex-$shell/config.toml"
    $settingsPath = Join-Path $output "claude-$shell/settings.json"
    & python (Join-Path $root 'scripts/validate-config.py') $tomlPath $settingsPath
    if ($LASTEXITCODE -ne 0) { throw "Generated configuration validation failed for $shell." }
    Test-CodexSchema $tomlPath
}

$leftoverPlaceholders = @(Get-ChildItem $output -File -Recurse | ForEach-Object {
    # __AI_CONFIG_ROOT__ is resolved at install time, once the destination is known; it is
    # expected to remain in generated output. -cmatch keeps this case-sensitive so Python
    # dunder names (__main__, __name__) in flashbang.sh are not mistaken for placeholders.
    $content = (Get-Content -LiteralPath $_.FullName -Raw) -replace '__AI_CONFIG_ROOT__|__POWERSHELL_COMMAND__', ''
    if ($content -cmatch '__[A-Z0-9_]+__' -and $content -notmatch '__CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY__') { $_.FullName }
})
if ($leftoverPlaceholders.Count) { throw "Unresolved template placeholders in: $($leftoverPlaceholders -join ', ')" }

if ($Summary) { Write-Output 'Build: PASS | 4 packages' } else { Write-Output 'PASS build: codex-powershell, claude-powershell, codex-bash, claude-bash' }
exit 0
