$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$powerShellHook = Get-Content -LiteralPath (Join-Path $root 'shared/hooks/flashbang.ps1') -Raw
$bashHook = Get-Content -LiteralPath (Join-Path $root 'shared/hooks/flashbang.sh') -Raw
if ($powerShellHook -notmatch '\$HoldMs\s*=\s*250' -or $powerShellHook -notmatch '\$FadeMs\s*=\s*250' -or ([regex]::Matches($bashHook, 'default=250').Count -lt 2)) { throw 'Flashbang defaults must total 500 milliseconds on Windows and Linux.' }
$statusInput = '{"model":{"display_name":"Test Model"},"effort":{"level":"high"},"workspace":{"current_dir":"' + $root.Replace('\','\\') + '","repo":{"name":"TestRepo"}},"context_window":{"context_window_size":200000,"used_percentage":8.5,"total_input_tokens":15500,"total_output_tokens":1200}}'
$branch = & git -C $root branch --show-current
$statusOutput = $statusInput | & (Join-Path $root 'shared/statusline/statusline.ps1')
if ($statusOutput -ne "Model: Test Model | Effort: high | Repo: TestRepo | Branch: $branch | Max Context: 200000 | Used Context: 9% | Used Tokens: 16700") { throw 'PowerShell status line output is incorrect.' }
$sourceAgentCount = @(Get-ChildItem (Join-Path $root 'shared/agents') -Directory).Count
$sourceSkillCount = @(Get-ChildItem (Join-Path $root 'shared/skills') -Filter 'SKILL.md' -Recurse).Count
$ruleSkillCount = @(Import-Csv -LiteralPath (Join-Path $root 'adapters/claude/rule-skills.tsv') -Delimiter ([char]9)).Count
foreach ($platform in @('windows','linux')) {
    foreach ($client in @('codex','claude')) {
        $package = Join-Path $root "generated/$client-$platform"
        $file = if ($client -eq 'codex') { 'config.toml' } else { 'settings.json' }
        $content = Get-Content -LiteralPath (Join-Path $package $file) -Raw
        if ($client -eq 'claude') { $settings = $content | ConvertFrom-Json }
        if (@(Get-ChildItem "$package/agents" -File).Count -ne $sourceAgentCount) { throw "Missing agents in $package" }
        $expectedSkillCount = if ($client -eq 'claude') { $sourceSkillCount + $ruleSkillCount } else { $sourceSkillCount }
        if (@(Get-ChildItem "$package/skills" -Filter SKILL.md -Recurse).Count -ne $expectedSkillCount) { throw "Missing skills in $package" }
        $expected = if ($platform -eq 'windows') { 'powershell .*flashbang.ps1' } else { 'bash .*flashbang.sh' }
        if ($content -notmatch $expected -or $content -match '__HOOK_|__WINDOWS_HOOK_') { throw "Incorrect platform command in $package" }
        if ($platform -eq 'windows' -and $content -match 'WindowStyle\s+Hidden') { throw "Windows hook hides the terminal in $package" }
        if ($client -eq 'codex') {
            $events = @([regex]::Matches($content, '(?m)^\[\[hooks\.([^.\]]+)\]\]\s*$') | ForEach-Object { $_.Groups[1].Value })
            if ($events.Count -ne 1 -or $events[0] -ne 'Stop' -or $content -match 'flashbang-if-input' -or $content -match '(?m)^async\s*=\s*true\s*$') { throw "Codex finish hook is incorrect in $package" }
            if ($content -notmatch 'approvals_reviewer\s*=\s*"auto_review"') { throw "Codex auto review is missing in $package" }
            if ($content -notmatch 'status_line\s*=\s*\["model", "reasoning", "project-name", "git-branch", "context-window-size", "context-used", "used-tokens"\]') { throw "Codex status line is incorrect in $package" }
        } elseif (@($settings.hooks.PSObject.Properties.Name).Count -ne 1 -or $settings.hooks.PSObject.Properties.Name -ne 'Stop' -or $content -match 'flashbang-if-input' -or $settings.hooks.Stop[0].hooks[0].async) {
            throw "Claude finish hook is incorrect in $package"
        } elseif ($content -notmatch '"defaultMode"\s*:\s*"auto"') {
            throw "Claude auto permission mode is missing in $package"
        } elseif (-not (Test-Path -LiteralPath (Join-Path $package "statusline/statusline.$(if ($platform -eq 'windows') { 'ps1' } else { 'sh' })")) -or $settings.statusLine.command -notmatch "statusline\.$(if ($platform -eq 'windows') { 'ps1' } else { 'sh' })") {
            throw "Claude status line is incorrect in $package"
        }
    }
}
foreach ($platformSelection in @('1','2')) {
    foreach ($clientSelection in @('1','2','3')) {
        $script:answers = [System.Collections.Generic.Queue[string]]::new()
        $script:answers.Enqueue($platformSelection)
        $script:answers.Enqueue($clientSelection)
        function Read-Host { param($Prompt) $answers.Dequeue() }
        $output = & "$PSScriptRoot/install.ps1" -DryRun
        if ($output -notcontains 'PASS install dry-run') { throw 'Dry-run did not finish.' }
        $platform = if ($platformSelection -eq '1') { 'windows' } else { 'linux' }
        if (($output -join "`n") -notmatch "-$platform") { throw 'Incorrect selected package.' }
    }
}
Write-Output 'PASS four platform packages and six PowerShell selections'

