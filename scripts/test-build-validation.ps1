[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$work = Join-Path ([System.IO.Path]::GetTempPath()) ("ai-config-build-validation-" + [Guid]::NewGuid())
New-Item $work -ItemType Directory -Force | Out-Null

function New-RepoCopy {
    $copy = Join-Path $work ("case-" + [Guid]::NewGuid())
    New-Item $copy -ItemType Directory -Force | Out-Null
    Get-ChildItem $root -Force | Where-Object { $_.Name -notin @('.git','generated') } | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $copy $_.Name) -Recurse -Force
    }
    return $copy
}

function Test-BuildFails([string]$Label, [scriptblock]$Mutate) {
    $copy = New-RepoCopy
    & $Mutate $copy
    $failed = $false
    try { & (Join-Path $copy 'scripts/build.ps1') 2>&1 | Out-Null }
    catch { $failed = $true }
    Remove-Item $copy -Recurse -Force -ErrorAction SilentlyContinue
    if (-not $failed) { throw "Expected build to fail for case '$Label' but it succeeded." }
}

Test-BuildFails 'invalid Claude settings.json' {
    param($copy)
    Add-Content (Join-Path $copy 'adapters/claude/config/settings.json') '} this is not json {'
}

Test-BuildFails 'duplicate agent name' {
    param($copy)
    $architect = Join-Path $copy 'shared/agents/architect/agent.yml'
    (Get-Content $architect -Raw) -replace 'name:\s*\S+', 'name: implementer' | Set-Content $architect -NoNewline
}

Test-BuildFails 'duplicate plugin name' {
    param($copy)
    $manifest = Join-Path $copy 'adapters/plugins.tsv'
    $lines = Get-Content $manifest
    Add-Content $manifest $lines[1]
}

Test-BuildFails 'leftover template placeholder' {
    param($copy)
    Add-Content (Join-Path $copy 'shared/global-instructions.md') "`n__NOT_A_REAL_PLACEHOLDER__"
}

Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
Write-Output 'PASS build validation: invalid JSON, duplicate agent, duplicate plugin, and leftover placeholders are all rejected'
