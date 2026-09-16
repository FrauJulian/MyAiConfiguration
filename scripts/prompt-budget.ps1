[CmdletBinding()]
param([switch]$Summary)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$generated = Join-Path $root 'generated'
if (-not (Test-Path (Join-Path $generated 'claude-linux/CLAUDE.md'))) { throw 'Generated output is missing; run build first.' }
function Measure-Tree([string]$path) {
    if (-not (Test-Path $path)) { return 0 }
    return [int64]((Get-ChildItem $path -File -Recurse | ForEach-Object { $_.Length } | Measure-Object -Sum).Sum)
}
function Tokens([int64]$bytes) { return [int][Math]::Ceiling($bytes / 4.0) }
$claude = (Get-Item (Join-Path $generated 'claude-linux/CLAUDE.md')).Length
$codex = (Get-Item (Join-Path $generated 'codex-linux/AGENTS.md')).Length
$skills = Measure-Tree (Join-Path $generated 'claude-linux/skills')
$triggers = (Get-Item (Join-Path $root 'adapters/claude/rule-skills.tsv')).Length
$lazyItem = Get-ChildItem (Join-Path $root 'shared/rules') -File -Recurse | Sort-Object Length -Descending | Select-Object -First 1
$lazy = if ($lazyItem) { [int64]$lazyItem.Length } else { 0 }
$baseline = Join-Path $root 'adapters/prompt-budget-baseline.json'
$old = if (Test-Path $baseline) { Get-Content $baseline -Raw | ConvertFrom-Json } else { $null }
$rows = @([pscustomobject]@{Name='Claude permanent context';Bytes=$claude;Tokens=(Tokens $claude)},[pscustomobject]@{Name='Codex permanent context';Bytes=$codex;Tokens=(Tokens $codex)},[pscustomobject]@{Name='Claude skill metadata';Bytes=$skills;Tokens=(Tokens $skills)},[pscustomobject]@{Name='Rule trigger metadata';Bytes=$triggers;Tokens=(Tokens $triggers)},[pscustomobject]@{Name='Largest lazy rule';Bytes=$lazy;Tokens=(Tokens $lazy)})
$fail = $false
if ($old) { foreach ($row in $rows | Select-Object -First 2) { $previous = [double]$old.($row.Name); if ($previous -gt 0 -and $row.Bytes -gt $previous * 1.15) { $fail = $true } } }
if ($Summary) { Write-Output 'Prompt Budget'; $rows | ForEach-Object { Write-Output ('{0,-28} {1,8} bytes  {2,6} tokens' -f $_.Name,$_.Bytes,$_.Tokens) } } else { $rows | ForEach-Object { Write-Output ('{0}: {1} bytes / {2} tokens' -f $_.Name,$_.Bytes,$_.Tokens) } }
if ($fail) { Write-Error 'Prompt budget: permanent context increased by more than 15 percent.'; exit 1 }
exit 0
