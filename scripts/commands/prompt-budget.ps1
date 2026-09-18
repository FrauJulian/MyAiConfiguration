[CmdletBinding()]
param([switch]$Summary)
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$generated = Join-Path $root 'generated'
if (-not (Test-Path (Join-Path $generated 'claude-bash/CLAUDE.md'))) { throw 'Generated output is missing; run build first.' }
function Measure-Tree([string]$path) {
    if (-not (Test-Path $path)) { return 0 }
    return [int64]((Get-ChildItem $path -File -Recurse | ForEach-Object { $_.Length } | Measure-Object -Sum).Sum)
}
function Tokens([int64]$bytes) { return [int][Math]::Ceiling($bytes / 4.0) }
$claude = (Get-Item (Join-Path $generated 'claude-bash/CLAUDE.md')).Length
$codex = (Get-Item (Join-Path $generated 'codex-bash/AGENTS.md')).Length
$skills = Measure-Tree (Join-Path $generated 'claude-bash/skills')
$triggers = (Get-Item (Join-Path $root 'adapters/rule-skills.tsv')).Length
$lazyItem = Get-ChildItem (Join-Path $root 'shared/rules') -File -Recurse | Sort-Object Length -Descending | Select-Object -First 1
$lazy = if ($lazyItem) { [int64]$lazyItem.Length } else { 0 }
$baseline = Join-Path $root 'adapters/prompt-budget-baseline.json'
$old = if (Test-Path $baseline) { Get-Content $baseline -Raw | ConvertFrom-Json } else { $null }
$rows = @([pscustomobject]@{Name='Claude permanent context';Bytes=$claude;Tokens=(Tokens $claude)},[pscustomobject]@{Name='Codex permanent context';Bytes=$codex;Tokens=(Tokens $codex)},[pscustomobject]@{Name='Claude skill files (lazy)';Bytes=$skills;Tokens=(Tokens $skills)},[pscustomobject]@{Name='Rule trigger metadata';Bytes=$triggers;Tokens=(Tokens $triggers)},[pscustomobject]@{Name='Largest lazy rule';Bytes=$lazy;Tokens=(Tokens $lazy)})
$fail = $false
$baselineValues = @{}
if ($old) {
    foreach ($row in $rows | Select-Object -First 2) {
        $previous = [double]$old.($row.Name)
        $absolute = [double]$old.(($row.Name + ' absolute limit'))
        $baselineValues[$row.Name] = @($previous, $absolute)
        if ($previous -gt 0 -and $row.Bytes -gt $previous * 1.15) { $fail = $true; Write-Error "Prompt budget relative limit failed: $($row.Name) $($row.Bytes) bytes (baseline $previous, limit 15%)." }
        if ($absolute -gt 0 -and $row.Bytes -gt $absolute) { $fail = $true; Write-Error "Prompt budget absolute limit failed: $($row.Name) $($row.Bytes) bytes (absolute limit $absolute)." }
    }
}
if ($Summary) { Write-Output 'Prompt Budget'; foreach ($row in $rows | Select-Object -First 2) { $limits = $baselineValues[$row.Name]; $base = if($limits){$limits[0]}else{'-'}; $absolute = if($limits){$limits[1]}else{'-'}; Write-Output ('{0,-28} {1,8} bytes  baseline {2}  relative 115%  absolute {3}' -f $row.Name,$row.Bytes,$base,$absolute) }; $rows | Select-Object -Skip 2 | ForEach-Object { Write-Output ('{0,-28} {1,8} bytes  {2,6} tokens' -f $_.Name,$_.Bytes,$_.Tokens) } } else { $rows | ForEach-Object { Write-Output ('{0}: {1} bytes / {2} tokens' -f $_.Name,$_.Bytes,$_.Tokens) } }
& python (Join-Path $root 'scripts/lib/prompt-inventory.py') --home ([Environment]::GetFolderPath('UserProfile'))
if ($LASTEXITCODE -ne 0) { throw 'Prompt inventory failed.' }
if ($fail) { exit 1 }
exit 0
