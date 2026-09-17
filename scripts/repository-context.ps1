[CmdletBinding()]
param([switch]$Force,[switch]$Summary)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$cacheDir = Join-Path $root '.ai-session'
$cachePath = Join-Path $cacheDir 'repository-context.json'
$safeRoot = $root.Replace('\','/')
$head = (& git -c "safe.directory=$safeRoot" -C $root rev-parse HEAD 2>$null).Trim()
$inputs = @('AI-Instructions.md','adapters/plugins.tsv','adapters/rule-skills.tsv','adapters/claude/capabilities.tsv','adapters/prompt-budget-baseline.json','adapters/prompt-budget-baseline.tsv','adapters/codex/config/config.toml','adapters/claude/config/settings.json')
$inputs += @(Get-ChildItem $root -File -Recurse | Where-Object { $_.FullName -notmatch '\\(generated|\.git|node_modules|bin|obj|vendor|\.ai-session)\\' -and $_.Extension -in @('.sln','.csproj','.fsproj','.ts','.tsx','.json','.toml','.yaml','.yml','.cs','.fs','.py','.sh','.ps1') } | ForEach-Object { $_.FullName.Substring($root.Length + 1) } | Sort-Object)
$keyText = $head + "`n" + (($inputs | Sort-Object -Unique | ForEach-Object { $_ + ':' + (Get-FileHash (Join-Path $root $_) -Algorithm SHA256).Hash }) -join "`n")
$key = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($keyText)).TrimEnd('=')
if (-not $Force -and (Test-Path $cachePath)) { try { $existing = Get-Content $cachePath -Raw | ConvertFrom-Json; if ($existing.invalidationKey -eq $key) { if ($Summary) { Write-Output 'Repository context: unchanged' }; exit 0 } } catch {} }
$extensions = @(Get-ChildItem $root -File -Recurse | Where-Object { $_.FullName -notmatch '\\(generated|\.git|node_modules|bin|obj|vendor|\.ai-session)\\' } | Group-Object Extension | Sort-Object Count -Descending)
$languages = @(); foreach ($item in $extensions) { switch ($item.Name.ToLowerInvariant()) { '.cs' { $languages += 'csharp' }; '.ts' { $languages += 'typescript' }; '.tsx' { $languages += 'typescript' }; '.py' { $languages += 'python' }; '.ps1' { $languages += 'powershell' }; '.sh' { $languages += 'bash' } } }
$languages = @($languages | Sort-Object -Unique)
$solutions = @(Get-ChildItem $root -Filter *.sln -File -Recurse | Where-Object { $_.FullName -notmatch '\\(generated|\.git)\\' } | ForEach-Object { $_.BaseName } | Sort-Object -Unique)
$tests = @(Get-ChildItem $root -File -Recurse | Where-Object { $_.Name -match '(?i)test' -and $_.FullName -notmatch '\\(generated|\.git|node_modules|bin|obj)\\' } | ForEach-Object { $_.BaseName } | Sort-Object -Unique)
$packageManager = if (Test-Path (Join-Path $root 'pnpm-lock.yaml')) { 'pnpm' } elseif (Test-Path (Join-Path $root 'package-lock.json')) { 'npm' } elseif (Test-Path (Join-Path $root 'yarn.lock')) { 'yarn' } else { $null }
$data = [ordered]@{ invalidationKey=$key; head=$head; languages=$languages; frameworks=@(); solutions=$solutions; testProjects=$tests; packageManager=$packageManager; buildCommands=[ordered]@{}; generatedAt=(Get-Date).ToUniversalTime().ToString('o') }
New-Item $cacheDir -ItemType Directory -Force | Out-Null
$data | ConvertTo-Json -Depth 5 | Set-Content $cachePath -Encoding UTF8
if ($Summary) { Write-Output ('Repository context: refreshed | {0} languages | {1} solutions | {2} tests' -f $languages.Count,$solutions.Count,$tests.Count) } else { Write-Output $cachePath }
