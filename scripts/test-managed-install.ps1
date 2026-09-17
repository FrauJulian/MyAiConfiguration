[CmdletBinding()]
param([switch]$Summary)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'lib/manifest.ps1')

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("ai-config-manifest-test-" + [Guid]::NewGuid())
New-Item $work -ItemType Directory -Force | Out-Null
try {
    $source = Join-Path $work 'source'
    $destination = Join-Path $work 'destination'
    New-Item $source -ItemType Directory -Force | Out-Null
    Set-Content (Join-Path $source 'a.md') 'A' -Encoding UTF8 -NoNewline
    Set-Content (Join-Path $source 'b.md') 'B' -Encoding UTF8 -NoNewline
    Set-Content (Join-Path $source 'c.md') 'C' -Encoding UTF8 -NoNewline

    $out1 = @(Sync-ManagedDestination -Source $source -Destination $destination -Stamp 'run1')
    if (@($out1 | Where-Object { $_ -like 'CREATE*' }).Count -ne 3) { throw "Expected three CREATE lines on first install: $($out1 -join '; ')" }

    $out2 = @(Sync-ManagedDestination -Source $source -Destination $destination -Stamp 'run2')
    if (@($out2 | Where-Object { $_ -notlike 'UNCHANGED*' -and $_ -notlike 'SOURCE *' }).Count -ne 0) { throw "Second identical install was not a no-op: $($out2 -join '; ')" }
    if (Test-Path (Join-Path $destination 'backups/run2')) { throw 'Idempotent install must not create a backup.' }

    Set-Content (Join-Path $destination 'foreign.md') 'mine' -Encoding UTF8 -NoNewline

    Remove-Item (Join-Path $source 'b.md') -Force
    Remove-Item (Join-Path $source 'c.md') -Force
    Set-Content (Join-Path $destination 'c.md') 'locally changed' -Encoding UTF8 -NoNewline

    $out3 = @(Sync-ManagedDestination -Source $source -Destination $destination -Stamp 'run3')
    if (@($out3 | Where-Object { $_ -match 'REMOVE.*b\.md' }).Count -ne 1) { throw "Expected b.md to be removed: $($out3 -join '; ')" }
    if (Test-Path (Join-Path $destination 'b.md')) { throw 'b.md should have been removed: it was untouched by the user and dropped from source.' }
    if (@($out3 | Where-Object { $_ -match 'WARN.*c\.md.*changed locally' }).Count -ne 1) { throw "Expected c.md to be flagged as locally modified: $($out3 -join '; ')" }
    if (-not (Test-Path (Join-Path $destination 'c.md'))) { throw 'A locally modified stale file must not be removed.' }
    if ((Get-Content (Join-Path $destination 'c.md') -Raw) -ne 'locally changed') { throw 'c.md content must be preserved exactly.' }
    if ((Get-Content (Join-Path $destination 'foreign.md') -Raw) -ne 'mine') { throw 'A file this setup never installed must never be touched.' }
    if (-not (Test-Path (Join-Path $destination 'backups/run3/b.md'))) { throw 'b.md should have been backed up before removal.' }
    if (-not (Test-Path (Join-Path $destination 'backups/run3/c.md'))) { throw 'c.md should have been backed up even though it was left in place.' }

    Remove-Item (Join-Path $source 'a.md') -Force
    $beforeDry = @(Get-ChildItem $destination -Recurse -File | Sort-Object FullName | ForEach-Object FullName)
    $outDry = @(Sync-ManagedDestination -Source $source -Destination $destination -Stamp 'dry' -DryRun)
    $afterDry = @(Get-ChildItem $destination -Recurse -File | Sort-Object FullName | ForEach-Object FullName)
    if (Compare-Object $beforeDry $afterDry) { throw 'A dry run must not change the destination at all.' }
    if (@($outDry | Where-Object { $_ -match 'DRYRUN REMOVE.*a\.md' }).Count -ne 1) { throw "Dry run should report the planned removal without performing it: $($outDry -join '; ')" }

    $configPath = Join-Path $destination 'config.toml'
    $pluginState = @'
  [marketplaces.ponytail]
    source_type = "git"
    source = "https://github.com/DietrichGebert/ponytail.git"
  [plugins."ponytail@ponytail"]
    enabled = true
  [plugins."disabled@market"]
    enabled = false
'@
    [System.IO.File]::WriteAllText((Join-Path $source 'config.toml'), "approvals_reviewer = 'auto_review'`n`n[tui]`n")
    [System.IO.File]::WriteAllText($configPath, "model = 'old'`nmodel_reasoning_effort = 'high'`napprovals_reviewer = 'user'`n$pluginState`n[other]`nvalue = true`n", (New-Object System.Text.UTF8Encoding($true)))
    $originalConfig = [System.IO.File]::ReadAllText($configPath)
    $null = Sync-ManagedDestination -Source $source -Destination $destination -Stamp 'plugins-dry' -DryRun
    if ([System.IO.File]::ReadAllText($configPath) -ne $originalConfig) { throw 'Dry run must preserve plugin configuration.' }
    $null = Sync-ManagedDestination -Source $source -Destination $destination -Stamp 'plugins'
    $mergedConfig = [System.IO.File]::ReadAllText($configPath)
    if (-not ($mergedConfig -replace "`r`n", "`n").Contains(($pluginState -replace "`r`n", "`n"))) { throw 'Updating config.toml must preserve local marketplace and plugin tables, including disabled plugins.' }
    if (-not $mergedConfig.Contains("model = 'old'") -or -not $mergedConfig.Contains("model_reasoning_effort = 'high'") -or -not $mergedConfig.Contains("approvals_reviewer = 'auto_review'") -or $mergedConfig.Contains("approvals_reviewer = 'user'") -or $mergedConfig.Contains('[other]')) { throw 'Updating config.toml must preserve local model settings and enforce automatic review.' }
    if ($mergedConfig.IndexOf("model = 'old'") -gt $mergedConfig.IndexOf('[tui]') -or $mergedConfig.IndexOf("model_reasoning_effort = 'high'") -gt $mergedConfig.IndexOf('[tui]')) { throw 'Model settings must remain in the TOML root table.' }
    if ([System.IO.File]::ReadAllText((Join-Path $destination 'backups/plugins/config.toml')) -ne $originalConfig) { throw 'Original plugin configuration must be backed up.' }
    $null = Sync-ManagedDestination -Source $source -Destination $destination -Stamp 'plugins-repeat'
    if ([System.IO.File]::ReadAllText($configPath) -ne $mergedConfig -or (Test-Path (Join-Path $destination 'backups/plugins-repeat'))) { throw 'Preserving plugin configuration must be idempotent.' }

    $outSummary = @(Sync-ManagedDestination -Source $source -Destination $destination -Stamp 'summary' -Summary)
    if (@($outSummary | Where-Object { $_ -like 'CREATE*' -or $_ -like 'UPDATE*' -or $_ -like 'UNCHANGED*' -or $_ -like 'BACKUP*' }).Count -ne 0) { throw "Summary mode must not print per-file lines: $($outSummary -join '; ')" }
    if (@($outSummary | Where-Object { $_ -match '^SYNC .* unchanged' }).Count -ne 1) { throw "Summary mode must print exactly one SYNC tally line: $($outSummary -join '; ')" }

    if ($Summary) { Write-Output 'Tests: PASS | managed install' } else { Write-Output 'PASS managed manifest: idempotent, stale removal, modified-file protection, foreign files preserved, dry run side-effect free' }
} finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
exit 0
