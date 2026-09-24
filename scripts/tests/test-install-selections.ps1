[CmdletBinding()]
param([switch]$Summary)
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
foreach ($shellSelection in @('1','2')) {
    foreach ($clientSelection in @('1','2','3')) {
        $script:answers = [System.Collections.Generic.Queue[string]]::new()
        $script:answers.Enqueue($shellSelection)
        $script:answers.Enqueue($clientSelection)
        function Read-Host { param($Prompt) $answers.Dequeue() }
        $output = & (Join-Path $root 'scripts/commands/install.ps1') -DryRun 6>$null
        if ($output -notcontains 'PASS install dry-run') { throw 'Dry-run did not finish.' }
        $shell = if ($shellSelection -eq '1') { 'powershell' } else { 'bash' }
        if (($output -join "`n") -notmatch "-$shell") { throw 'Incorrect selected package.' }
    }
}
if ($Summary) { Write-Output 'Tests: PASS | install selections' } else { Write-Output 'PASS six shell and client selections' }
exit 0
