[CmdletBinding()]
param([switch]$Summary)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'lib/manifest.ps1')
$homePath = [Environment]::GetFolderPath('UserProfile')
$script:fail = $false
$script:checkCount = 0
function Result($state, $message) {
    $script:checkCount++
    if ($state -eq 'FAIL') { $script:fail = $true }
    if (-not $Summary -or $script:fail -or $state -ne 'PASS') { Write-Output ("$state $message") }
}

foreach ($tool in @('codex','claude')) { if (Get-Command $tool -ErrorAction SilentlyContinue) { $version = & $tool --version 2>&1 | Select-Object -First 1; Result 'PASS' "$tool available ($version)" } else { Result 'WARN' "$tool unavailable" } }
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) { if (Get-Command jq -ErrorAction SilentlyContinue) { Result 'PASS' 'jq available for Claude status line' } else { Result 'WARN' 'jq unavailable; Claude status line is disabled' } }

$sourceAgentCount = @(Get-ChildItem (Join-Path $root 'shared/agents') -Directory -ErrorAction SilentlyContinue).Count
$sourceSkillCount = @(Get-ChildItem (Join-Path $root 'shared/skills') -Filter 'SKILL.md' -Recurse -ErrorAction SilentlyContinue).Count
$ruleSkillManifestPath = Join-Path $root 'adapters/claude/rule-skills.tsv'
$ruleSkillCount = if (Test-Path -LiteralPath $ruleSkillManifestPath) { @(Import-Csv -LiteralPath $ruleSkillManifestPath -Delimiter ([char]9)).Count } else { 0 }

foreach ($platform in @('windows','linux')) {
    if (Test-Path (Join-Path $root "generated/codex-$platform/AGENTS.md")) { Result 'PASS' "generated output present ($platform)" } else { Result 'FAIL' "generated output missing ($platform); run build" }
    if ((Test-Path (Join-Path $root "generated/codex-$platform/hooks/scripts/Validate-CommandSafety.ps1")) -and (Test-Path (Join-Path $root "generated/codex-$platform/hooks/scripts/validate-command-safety.sh")) -and (Test-Path (Join-Path $root "generated/claude-$platform/hooks/scripts/Validate-CommandSafety.ps1")) -and (Test-Path (Join-Path $root "generated/claude-$platform/hooks/scripts/validate-command-safety.sh"))) { Result 'PASS' "generated hooks present ($platform)" } else { Result 'FAIL' "generated hooks missing ($platform); run build" }
    foreach ($client in @('codex','claude')) {
        $package = Join-Path $root "generated/$client-$platform"
        if (-not (Test-Path $package)) { continue }
        $agentCount = @(Get-ChildItem (Join-Path $package 'agents') -File -ErrorAction SilentlyContinue).Count
        if ($agentCount -eq $sourceAgentCount) { Result 'PASS' "$client-$platform agent count matches source ($agentCount)" } else { Result 'FAIL' "$client-$platform agent count $agentCount does not match source ($sourceAgentCount)" }
        $expectedSkillCount = if ($client -eq 'claude') { $sourceSkillCount + $ruleSkillCount } else { $sourceSkillCount }
        $skillCount = @(Get-ChildItem (Join-Path $package 'skills') -Filter 'SKILL.md' -Recurse -ErrorAction SilentlyContinue).Count
        if ($skillCount -eq $expectedSkillCount) { Result 'PASS' "$client-$platform skill count matches source ($skillCount)" } else { Result 'FAIL' "$client-$platform skill count $skillCount does not match source ($expectedSkillCount)" }
        $placeholderHits = @(Get-ChildItem $package -File -Recurse | Where-Object { ((Get-Content -LiteralPath $_.FullName -Raw) -replace '__AI_CONFIG_ROOT__', '') -cmatch '__[A-Z0-9_]+__' })
        if ($placeholderHits.Count -eq 0) { Result 'PASS' "$client-$platform has no unresolved placeholders" } else { Result 'FAIL' "$client-$platform has unresolved placeholders: $($placeholderHits.FullName -join ', ')" }
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
    try { $parseResult = & python -c 'import sys,tomllib,pathlib; tomllib.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8-sig"))' $configTomlPath 2>&1 } catch { $parseResult = $_ }
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
    if ($script:fail) { Write-Output "Doctor: FAIL | $script:checkCount checks"; exit 1 }
    Write-Output "Doctor: PASS | $script:checkCount checks"
} else {
    if ($script:fail) { exit 1 }
    Write-Output 'PASS doctor'
}
exit 0
