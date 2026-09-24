[CmdletBinding()]
param([switch]$Summary)
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$sourceAgentCount = @(Get-ChildItem (Join-Path $root 'shared/agents') -Directory).Count
$sourceSkillCount = @(Get-ChildItem (Join-Path $root 'shared/skills') -Filter 'SKILL.md' -Recurse).Count
$rulesRoot = Join-Path $root 'shared/rules'
$ruleSources = @()
foreach ($ruleFile in Get-ChildItem $rulesRoot -File -Filter '*.md' | Where-Object Name -ne 'general.md') {
    $ruleSources += [pscustomobject]@{ Path = $ruleFile.Name; Skill = "rules-$($ruleFile.BaseName)" }
}
foreach ($ruleDirectory in Get-ChildItem $rulesRoot -Directory) {
    if (Test-Path (Join-Path $ruleDirectory.FullName 'index.md')) { $ruleSources += [pscustomobject]@{ Path = "$($ruleDirectory.Name)/index.md"; Skill = "rules-$($ruleDirectory.Name)" } }
}
$ruleSkillCount = $ruleSources.Count
$globalInstructions = Get-Content (Join-Path $root 'shared/global-instructions.md') -Raw
foreach ($ruleSource in $ruleSources) {
    $ruleInstruction = [char]96 + "rules/$($ruleSource.Path)" + [char]96 + ' / ' + [char]96 + $ruleSource.Skill + [char]96
    if (-not $globalInstructions.Contains($ruleInstruction)) { throw "Global instructions are missing rule loading entry: $($ruleSource.Path)" }
}
foreach ($shell in @('powershell','bash')) {
    foreach ($client in @('codex','claude')) {
        $package = Join-Path $root "generated/$client-$shell"
        $file = if ($client -eq 'codex') { 'config.toml' } else { 'settings.json' }
        $content = Get-Content -LiteralPath (Join-Path $package $file) -Raw
        if ($client -eq 'claude') { $settings = $content | ConvertFrom-Json }
        if (@(Get-ChildItem "$package/agents" -File).Count -ne $sourceAgentCount) { throw "Missing agents in $package" }
        $expectedReviewerShellTool = if ($shell -eq 'powershell') { 'PowerShell' } else { 'Bash' }
        if ($client -eq 'claude' -and (Get-Content (Join-Path $package 'agents/reviewer.md') -Raw) -notmatch "(?m)^tools: Read,Grep,Glob,$expectedReviewerShellTool\r?`$") { throw "Reviewer capability profile is missing in $package" }
        $expectedSkillCount = if ($client -eq 'claude') { $sourceSkillCount + $ruleSkillCount } else { $sourceSkillCount }
        if (@(Get-ChildItem "$package/skills" -Filter SKILL.md -Recurse).Count -ne $expectedSkillCount) { throw "Missing skills in $package" }
        $expected = if ($shell -eq 'powershell') { '__POWERSHELL_COMMAND__ .*flashbang.ps1' } else { 'bash .*flashbang.sh' }
        if ($content -notmatch $expected -or $content -match '__HOOK_|__POWERSHELL_HOOK_') { throw "Incorrect shell command in $package" }
        if ($shell -eq 'powershell' -and $content -match 'WindowStyle\s+Hidden') { throw "PowerShell hook hides the terminal in $package" }
        if ($client -eq 'codex') {
            $events = @([regex]::Matches($content, '(?m)^\[\[hooks\.([^.\]]+)\]\]\s*$') | ForEach-Object { $_.Groups[1].Value })
            if ($events.Count -ne 1 -or $events[0] -ne 'Stop' -or $content -match 'flashbang-if-input' -or $content -match '(?m)^async\s*=\s*true\s*$') { throw "Codex finish hook is incorrect in $package" }
            if ($content -notmatch 'approvals_reviewer\s*=\s*"auto_review"') { throw "Codex auto review is missing in $package" }
            if ($content -notmatch '(?m)^max_depth\s*=\s*1\s*$') { throw "Codex agent depth limit is missing in $package" }
            if ($content -notmatch 'status_line\s*=\s*\["model", "reasoning", "approval-mode", "project-name", "git-branch", "context-window-size", "context-used", "used-tokens"\]') { throw "Codex status line is incorrect in $package" }
        } elseif ((($settings.hooks.PSObject.Properties.Name | Sort-Object) -join ',') -ne 'PreCompact,SessionStart,Stop' -or $content -match 'flashbang-if-input' -or $settings.hooks.Stop[0].hooks[0].async) {
            throw "Claude finish hook is incorrect in $package"
        } elseif ($content -notmatch '"defaultMode"\s*:\s*"auto"') {
            throw "Claude auto permission mode is missing in $package"
        } elseif ($shell -eq 'powershell' -and ($settings.sandbox.enabled -ne $false -or $settings.sandbox.PSObject.Properties.Count -ne 1)) {
            throw "Claude sandbox must be disabled in $package"
        } elseif ($shell -eq 'bash' -and (-not $settings.sandbox.enabled -or $settings.sandbox.allowUnsandboxedCommands -ne $false -or $settings.sandbox.failIfUnavailable -ne $true)) {
            throw "Claude strict sandbox is missing in $package"
        } elseif (-not (Test-Path -LiteralPath (Join-Path $package "statusline/statusline.$(if ($shell -eq 'powershell') { 'ps1' } else { 'sh' })")) -or $settings.statusLine.command -notmatch "statusline\.$(if ($shell -eq 'powershell') { 'ps1' } else { 'sh' })") {
            throw "Claude status line is incorrect in $package"
        }
        $docFile = if ($client -eq 'codex') { 'AGENTS.md' } else { 'CLAUDE.md' }
        $docContent = Get-Content -LiteralPath (Join-Path $package $docFile) -Raw
        if ($docContent -notmatch [regex]::Escape('rules/security.md')) { throw "$package is missing common rule loading instructions." }
        if ($client -eq 'claude') {
            foreach ($ruleSource in $ruleSources) {
                $skillPath = Join-Path $package "skills/rules/$($ruleSource.Skill)/SKILL.md"
                if (-not (Test-Path -LiteralPath $skillPath)) { throw "$package is missing generated skill $($ruleSource.Skill)." }
            }
        }
        if ($docContent -notmatch [regex]::Escape('Use the `mcporter` CLI for MCP services by default.')) { throw "$package must set the MCPorter default" }
        if ($docContent -notmatch [regex]::Escape('Use a native MCP connection when MCPorter is not active, or when the user explicitly requests it or selects a native MCP plugin in this configuration.')) { throw "$package must allow the selected native MCP route" }
        if (([regex]::Matches($docContent, [regex]::Escape('Apply instructions in this order'))).Count -ne 1) { throw "$client-$shell must embed the priority rule exactly once" }
        if ($client -eq 'codex' -and $docContent -match 'Always load and apply `rules/general\.md`') { throw "$package must not still instruct loading general.md by path" }
        if ($client -eq 'claude' -and (Test-Path (Join-Path $package 'rules/general.md'))) { throw 'Claude must not automatically load a second copy of general rules.' }
        foreach ($splitRule in @('angular','wpf','ui-ux')) {
            $referencesDir = if ($client -eq 'codex') { Join-Path $package "rules/$splitRule/references" } else { Join-Path $package "skills/rules/rules-$splitRule/references" }
            if (-not (Test-Path $referencesDir) -or (Get-ChildItem $referencesDir -Filter '*.md').Count -eq 0) { throw "$package is missing reference files for $splitRule" }
        }
    }
}
if ($Summary) { Write-Output 'Tests: PASS | generated packages' } else { Write-Output 'PASS four generated client and shell packages' }
exit 0
