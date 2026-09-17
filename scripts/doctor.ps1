[CmdletBinding()]
param([switch]$Summary)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'lib/manifest.ps1')
$homePath = [Environment]::GetFolderPath('UserProfile')
$script:fail = $false
$script:checkCount = 0
$script:passBuffer = @()
function Result($state, $message) {
    $script:checkCount++
    if ($state -eq 'FAIL') { $script:fail = $true }
    if ($Summary -and $state -eq 'PASS') {
        $script:passBuffer += "$state $message"
    } else {
        Write-Output ("$state $message")
    }
}

foreach ($tool in @('codex','claude')) { if (Get-Command $tool -ErrorAction SilentlyContinue) { $version = & $tool --version 2>&1 | Select-Object -First 1; Result 'PASS' "$tool available ($version)" } else { Result 'WARN' "$tool unavailable" } }
if (Get-Command jq -ErrorAction SilentlyContinue) { Result 'PASS' 'jq available for Claude Bash status line' } else { Result 'WARN' 'jq unavailable; Claude Bash status line is disabled' }

$sourceAgentCount = @(Get-ChildItem (Join-Path $root 'shared/agents') -Directory -ErrorAction SilentlyContinue).Count
$sourceSkillCount = @(Get-ChildItem (Join-Path $root 'shared/skills') -Filter 'SKILL.md' -Recurse -ErrorAction SilentlyContinue).Count
$ruleSkillManifestPath = Join-Path $root 'adapters/rule-skills.tsv'
$ruleSkillCount = if (Test-Path -LiteralPath $ruleSkillManifestPath) { @(Import-Csv -LiteralPath $ruleSkillManifestPath -Delimiter ([char]9)).Count } else { 0 }

foreach ($shell in @('powershell','bash')) {
    if (Test-Path (Join-Path $root "generated/codex-$shell/AGENTS.md")) { Result 'PASS' "generated output present ($shell)" } else { Result 'FAIL' "generated output missing ($shell); run build" }
    if ((Test-Path (Join-Path $root "generated/codex-$shell/hooks/scripts/Validate-CommandSafety.ps1")) -and (Test-Path (Join-Path $root "generated/codex-$shell/hooks/scripts/validate-command-safety.sh")) -and (Test-Path (Join-Path $root "generated/claude-$shell/hooks/scripts/Validate-CommandSafety.ps1")) -and (Test-Path (Join-Path $root "generated/claude-$shell/hooks/scripts/validate-command-safety.sh"))) { Result 'PASS' "generated hooks present ($shell)" } else { Result 'FAIL' "generated hooks missing ($shell); run build" }
    foreach ($client in @('codex','claude')) {
        $package = Join-Path $root "generated/$client-$shell"
        if (-not (Test-Path $package)) { continue }
        $agentCount = @(Get-ChildItem (Join-Path $package 'agents') -File -ErrorAction SilentlyContinue).Count
        if ($agentCount -eq $sourceAgentCount) { Result 'PASS' "$client-$shell agent count matches source ($agentCount)" } else { Result 'FAIL' "$client-$shell agent count $agentCount does not match source ($sourceAgentCount)" }
        $expectedSkillCount = if ($client -eq 'claude') { $sourceSkillCount + $ruleSkillCount } else { $sourceSkillCount }
        $skillCount = @(Get-ChildItem (Join-Path $package 'skills') -Filter 'SKILL.md' -Recurse -ErrorAction SilentlyContinue).Count
        if ($skillCount -eq $expectedSkillCount) { Result 'PASS' "$client-$shell skill count matches source ($skillCount)" } else { Result 'FAIL' "$client-$shell skill count $skillCount does not match source ($expectedSkillCount)" }
        $placeholderHits = @(Get-ChildItem $package -File -Recurse | Where-Object { ((Get-Content -LiteralPath $_.FullName -Raw) -replace '__AI_CONFIG_ROOT__|__POWERSHELL_COMMAND__|__CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY__', '') -cmatch '__[A-Z0-9_]+__' })
        if ($placeholderHits.Count -eq 0) { Result 'PASS' "$client-$shell has no unresolved placeholders" } else { Result 'FAIL' "$client-$shell has unresolved placeholders: $($placeholderHits.FullName -join ', ')" }
    }
}

foreach ($path in @('.codex/AGENTS.md','.codex/config.toml','.claude/CLAUDE.md','.claude/settings.json')) {
    if (Test-Path (Join-Path $homePath $path)) { Result 'PASS' "installed $path" } else { Result 'WARN' "not installed $path" }
}

$settingsPath = Join-Path $homePath '.claude/settings.json'
if (Test-Path -LiteralPath $settingsPath) {
    try { Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json | Out-Null; Result 'PASS' 'installed .claude/settings.json is valid JSON' }
    catch { Result 'FAIL' 'installed .claude/settings.json is not valid JSON' }
}
$configTomlPath = Join-Path $homePath '.codex/config.toml'
if (Test-Path -LiteralPath $configTomlPath) {
    $parseResult = & python -c "import sys,tomllib,pathlib; tomllib.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8-sig'))" $configTomlPath 2>&1
    if ($LASTEXITCODE -eq 0) { Result 'PASS' 'installed .codex/config.toml parses as TOML' } else { Result 'FAIL' "installed .codex/config.toml is invalid TOML: $parseResult" }
    if (Get-Command codex -ErrorAction SilentlyContinue) {
        $previousCodexHome = $env:CODEX_HOME
        try {
            $env:CODEX_HOME = Split-Path $configTomlPath -Parent
            $schemaResult = & codex --strict-config --help 2>&1
            if ($LASTEXITCODE -eq 0) { Result 'PASS' 'installed .codex/config.toml matches the installed Codex schema' } else { Result 'FAIL' "installed .codex/config.toml has unsupported Codex settings: $schemaResult" }
        } finally { $env:CODEX_HOME = $previousCodexHome }
    } else { Result 'WARN' 'Codex CLI unavailable; skipped installed Codex schema validation' }
}

foreach ($destination in @((Join-Path $homePath '.codex'), (Join-Path $homePath '.agents/skills'), (Join-Path $homePath '.claude'))) {
    $manifestPath = Get-ManagedManifestPath $destination
    if (-not (Test-Path -LiteralPath $manifestPath)) { continue }
    $manifest = Read-ManagedManifest $manifestPath
    $missing = @()
    $modified = @()
    foreach ($relative in $manifest.Keys) {
        $target = Join-Path $destination $relative
        if (-not (Test-Path -LiteralPath $target)) { $missing += $relative; continue }
        if ((Get-Sha256Hash $target) -ne $manifest[$relative]) { $modified += $relative }
    }
    if ($missing.Count) { Result 'WARN' "$destination is missing managed files: $($missing -join ', ')" } else { Result 'PASS' "$destination has no missing managed files" }
    if ($modified.Count) { Result 'WARN' "$destination has locally modified managed files: $($modified -join ', ')" } else { Result 'PASS' "$destination has no locally modified managed files" }
}

foreach ($path in @('shared/rules','shared/skills','shared/agents','shared/hooks/scripts')) { if (Test-Path (Join-Path $root $path)) { Result 'PASS' "source $path" } else { Result 'FAIL' "missing $path" } }

foreach ($client in @('codex','claude')) {
    $config = if ($client -eq 'codex') { Join-Path $root 'adapters/codex/config/config.toml' } else { Join-Path $root 'adapters/claude/config/settings.json' }
    $registered = if ($client -eq 'codex') { (Get-Content $config -Raw) -match '\[\[hooks\.Stop\]\]' } else { ((Get-Content $config -Raw | ConvertFrom-Json).hooks.PSObject.Properties.Name -contains 'Stop') }
    if ($registered) { Result 'PASS' "$client Stop hook is registered" } else { Result 'WARN' "$client ships hook utilities, but no Stop hook is registered" }
}

if ($Summary) {
    if ($script:fail) {
        $script:passBuffer | ForEach-Object { Write-Output $_ }
        Write-Output "Doctor: FAIL | $script:checkCount checks"
        exit 1
    }
    Write-Output "Doctor: PASS | $script:checkCount checks"
} else {
    if ($script:fail) { exit 1 }
    Write-Output 'PASS doctor'
}
exit 0
