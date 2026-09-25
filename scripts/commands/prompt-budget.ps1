[CmdletBinding()]
param([switch]$Summary)
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$budgetScript = Join-Path $root 'scripts/lib/prompt-budget.py'
$budgetArgs = @()
if ($Summary) { $budgetArgs += '--summary' }
& python $budgetScript @budgetArgs
$budgetExit = $LASTEXITCODE
& python (Join-Path $root 'scripts/lib/prompt-inventory.py') --home ([Environment]::GetFolderPath('UserProfile'))
if ($LASTEXITCODE -ne 0) { throw 'Prompt inventory failed.' }
exit $budgetExit
