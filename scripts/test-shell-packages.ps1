[CmdletBinding()]
param([switch]$Summary)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$powerShellHook = Get-Content -LiteralPath (Join-Path $root 'shared/hooks/flashbang.ps1') -Raw
$bashHook = Get-Content -LiteralPath (Join-Path $root 'shared/hooks/flashbang.sh') -Raw
if ($powerShellHook -notmatch '\$HoldMs\s*=\s*250' -or $powerShellHook -notmatch '\$FadeMs\s*=\s*250' -or ([regex]::Matches($bashHook, 'default=250').Count -lt 2)) { throw 'Flashbang defaults must total 500 milliseconds on PowerShell and Bash.' }
$statusInput = '{"model":{"display_name":"Test Model"},"effort":{"level":"high"},"workspace":{"current_dir":"' + $root.Replace('\','\\') + '","repo":{"name":"TestRepo"}},"context_window":{"context_window_size":200000,"used_percentage":8.5,"total_input_tokens":15500,"total_output_tokens":1200}}'
$branch = & git -C $root branch --show-current
$buildSummaryOutput = & (Join-Path $root 'scripts/build.ps1') -Summary
if (@($buildSummaryOutput | Where-Object { $_ -eq 'Build: PASS | 4 packages' }).Count -ne 1) { throw "build.ps1 -Summary must still print the PASS line: $($buildSummaryOutput -join '; ')" }
$statusOutput = ($statusInput | & (Join-Path $root 'shared/statusline/statusline.ps1')) -join "`n"
$plainStatusOutput = [regex]::Replace($statusOutput, [char]27 + '\[[0-9;]*m', '')
$expectedStatusOutput = "Test Model $([char]0x00B7) Effort high $([char]0x00B7) TestRepo @ $branch`nCtx 200k $([char]0x00B7) Used 9% $([char]0x00B7) Tokens 16.7k"
if ($buildSummaryOutput.Count -ne 1) { throw 'Build summary must contain only one success line.' }
if ($plainStatusOutput -ne $expectedStatusOutput) { throw 'PowerShell status line output is incorrect.' }
$sourceAgentCount = @(Get-ChildItem (Join-Path $root 'shared/agents') -Directory).Count
$sourceSkillCount = @(Get-ChildItem (Join-Path $root 'shared/skills') -Filter 'SKILL.md' -Recurse).Count
$ruleSkillCount = @(Import-Csv -LiteralPath (Join-Path $root 'adapters/claude/rule-skills.tsv') -Delimiter ([char]9)).Count
foreach ($shell in @('powershell','bash')) {
    foreach ($client in @('codex','claude')) {
        $package = Join-Path $root "generated/$client-$shell"
        $file = if ($client -eq 'codex') { 'config.toml' } else { 'settings.json' }
        $content = Get-Content -LiteralPath (Join-Path $package $file) -Raw
        if ($client -eq 'codex') {
            foreach ($entry in @(Import-Csv (Join-Path $root 'adapters/claude/rule-skills.tsv') -Delimiter ([char]9))) {
                $rulePath = $entry.rule_file
                if (Test-Path (Join-Path $root "shared/rules/$($entry.rule_file)") -PathType Container) { $rulePath = "$($entry.rule_file)/index.md" }
                if ((Get-Content (Join-Path $package 'AGENTS.md') -Raw) -notmatch [regex]::Escape("- rules/$rulePath for $($entry.trigger).")) { throw "Codex rule loading is missing $($entry.rule_file) in $package" }
            }
        }
        if ($client -eq 'claude') { $settings = $content | ConvertFrom-Json }
        if (@(Get-ChildItem "$package/agents" -File).Count -ne $sourceAgentCount) { throw "Missing agents in $package" }
        if ($client -eq 'claude' -and (Get-Content (Join-Path $package 'agents/reviewer.md') -Raw) -notmatch '(?m)^tools: Read,Diff,Search\r?$') { throw "Reviewer capability profile is missing in $package" }
        $expectedSkillCount = if ($client -eq 'claude') { $sourceSkillCount + $ruleSkillCount } else { $sourceSkillCount }
        if (@(Get-ChildItem "$package/skills" -Filter SKILL.md -Recurse).Count -ne $expectedSkillCount) { throw "Missing skills in $package" }
        $expected = if ($shell -eq 'powershell') { '__POWERSHELL_COMMAND__ .*flashbang.ps1' } else { 'bash .*flashbang.sh' }
        if ($content -notmatch $expected -or $content -match '__HOOK_|__POWERSHELL_HOOK_') { throw "Incorrect shell command in $package" }
        if ($shell -eq 'powershell' -and $content -match 'WindowStyle\s+Hidden') { throw "PowerShell hook hides the terminal in $package" }
        if ($client -eq 'codex') {
            $events = @([regex]::Matches($content, '(?m)^\[\[hooks\.([^.\]]+)\]\]\s*$') | ForEach-Object { $_.Groups[1].Value })
            if ($events.Count -ne 1 -or $events[0] -ne 'Stop' -or $content -match 'flashbang-if-input' -or $content -match '(?m)^async\s*=\s*true\s*$') { throw "Codex finish hook is incorrect in $package" }
            if ($content -notmatch 'approvals_reviewer\s*=\s*"auto_review"') { throw "Codex auto review is missing in $package" }
            if ($content -notmatch 'status_line\s*=\s*\["model", "reasoning", "project-name", "git-branch", "context-window-size", "context-used", "used-tokens"\]') { throw "Codex status line is incorrect in $package" }
        } elseif ((($settings.hooks.PSObject.Properties.Name | Sort-Object) -join ',') -ne 'PreCompact,SessionStart,Stop' -or $content -match 'flashbang-if-input' -or $settings.hooks.Stop[0].hooks[0].async) {
            throw "Claude finish hook is incorrect in $package"
        } elseif ($content -notmatch '"defaultMode"\s*:\s*"auto"') {
            throw "Claude auto permission mode is missing in $package"
        } elseif (-not (Test-Path -LiteralPath (Join-Path $package "statusline/statusline.$(if ($shell -eq 'powershell') { 'ps1' } else { 'sh' })")) -or $settings.statusLine.command -notmatch "statusline\.$(if ($shell -eq 'powershell') { 'ps1' } else { 'sh' })") {
            throw "Claude status line is incorrect in $package"
        }
        $docFile = if ($client -eq 'codex') { 'AGENTS.md' } else { 'CLAUDE.md' }
        $docContent = Get-Content -LiteralPath (Join-Path $package $docFile) -Raw
        if (([regex]::Matches($docContent, [regex]::Escape('Apply instructions in this order'))).Count -ne 1) { throw "$client-$shell must embed the priority rule exactly once" }
        if ($client -eq 'codex' -and $docContent -match 'Always load and apply `rules/general\.md`') { throw "$package must not still instruct loading general.md by path" }
        if ($client -eq 'claude' -and (Test-Path (Join-Path $package 'rules/general.md'))) { throw 'Claude must not automatically load a second copy of general rules.' }
        foreach ($splitRule in @('angular','wpf','ui-ux')) {
            $referencesDir = if ($client -eq 'codex') { Join-Path $package "rules/$splitRule/references" } else { Join-Path $package "skills/rules/rules-$splitRule/references" }
            if (-not (Test-Path $referencesDir) -or (Get-ChildItem $referencesDir -Filter '*.md').Count -eq 0) { throw "$package is missing reference files for $splitRule" }
        }
    }
}
foreach ($shellSelection in @('1','2')) {
    foreach ($clientSelection in @('1','2','3')) {
        $script:answers = [System.Collections.Generic.Queue[string]]::new()
        $script:answers.Enqueue($shellSelection)
        $script:answers.Enqueue($clientSelection)
        function Read-Host { param($Prompt) $answers.Dequeue() }
        $output = & "$PSScriptRoot/install.ps1" -DryRun 6>$null
        if ($output -notcontains 'PASS install dry-run') { throw 'Dry-run did not finish.' }
        $shell = if ($shellSelection -eq '1') { 'powershell' } else { 'bash' }
        if (($output -join "`n") -notmatch "-$shell") { throw 'Incorrect selected package.' }
    }
}
$doctorSummaryOutput = & (Join-Path $root 'scripts/doctor.ps1') -Summary
if (@($doctorSummaryOutput | Where-Object { $_ -match '^PASS ' }).Count -ne 0) { throw 'Doctor summary mode must not print individual PASS lines.' }
if (@($doctorSummaryOutput | Where-Object { $_ -match '^Doctor: PASS \| \d+ checks$' }).Count -ne 1) { throw "Doctor summary mode must print one 'Doctor: PASS | N checks' line: $($doctorSummaryOutput -join '; ')" }
foreach ($entryPoint in @('install','update')) {
    $preview = @(& "$PSScriptRoot/$entryPoint.ps1" -Summary -DryRun -Client Both -Shell PowerShell)
    if ($preview -match '^(SOURCE|CREATE|UPDATE|UNCHANGED|BACKUP|DRYRUN|PASS) ') { throw "$entryPoint summary leaked per-item output." }
    if (@($preview | Where-Object { $_ -match ('^' + $entryPoint + ': PASS') }).Count -ne 1) { throw "$entryPoint summary is missing." }
}
$doctorSummaryOutput | Where-Object { $_ -match '^WARN ' }
if ($Summary) { Write-Output 'Tests: PASS | shell packages' } else { Write-Output 'PASS four shell packages and six PowerShell selections' }
exit 0

