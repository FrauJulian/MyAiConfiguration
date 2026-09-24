[CmdletBinding()]
param([switch]$Summary)
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$powerShellHook = Get-Content -LiteralPath (Join-Path $root 'shared/hooks/flashbang.ps1') -Raw
$bashHook = Get-Content -LiteralPath (Join-Path $root 'shared/hooks/flashbang.sh') -Raw
if ($powerShellHook -notmatch '\$HoldMs\s*=\s*250' -or $powerShellHook -notmatch '\$FadeMs\s*=\s*250' -or ([regex]::Matches($bashHook, 'default=250').Count -lt 2)) { throw 'Flashbang defaults must total 500 milliseconds on PowerShell and Bash.' }
$statusInput = '{"model":{"display_name":"Test Model"},"effort":{"level":"high"},"workspace":{"current_dir":"' + $root.Replace('\','\\') + '","repo":{"name":"TestRepo"}},"context_window":{"context_window_size":200000,"used_percentage":8.5,"total_input_tokens":15500,"total_output_tokens":1200}}'
$branch = & git -C $root branch --show-current
$buildSummaryOutput = & (Join-Path $root 'scripts/commands/build.ps1') -Summary
if (@($buildSummaryOutput | Where-Object { $_ -eq 'Build: PASS | 4 packages' }).Count -ne 1) { throw "build.ps1 -Summary must still print the PASS line: $($buildSummaryOutput -join '; ')" }
$statusOutput = ($statusInput | & (Join-Path $root 'shared/statusline/statusline.ps1')) -join "`n"
$plainStatusOutput = [regex]::Replace($statusOutput, [char]27 + '\[[0-9;]*m', '')
$expectedStatusOutput = "Test Model $([char]0x00B7) Review auto $([char]0x00B7) Effort high $([char]0x00B7) TestRepo @ $branch`nCtx 200k $([char]0x00B7) Used 9% $([char]0x00B7) Tokens 16.7k"
if ($buildSummaryOutput.Count -ne 1) { throw 'Build summary must contain only one success line.' }
if ($plainStatusOutput -ne $expectedStatusOutput) { throw 'PowerShell status line output is incorrect.' }
if ($Summary) { Write-Output 'Tests: PASS | runtime status' } else { Write-Output 'PASS build summary and status lines' }
exit 0
