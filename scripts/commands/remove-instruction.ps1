[CmdletBinding()]
param(
    [ValidateSet('Codex','Claude','Both')][string]$Client,
    [AllowEmptyString()][string]$Instruction,
    [string]$HomePath = [Environment]::GetFolderPath('UserProfile')
)
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $root 'scripts/lib/install-targets.ps1')

if (-not $Client) { $Client = Read-InstallClient -Client $Client }
if (-not $PSBoundParameters.ContainsKey('Instruction')) { $Instruction = Read-Host 'Instruction to remove' }
if ([string]::IsNullOrWhiteSpace($Instruction) -or $Instruction.Length -gt 65536) { throw 'Instruction must contain between 1 and 65536 characters.' }
& python (Join-Path $root 'scripts/lib/remove-instruction.py') --client $Client.ToLowerInvariant() --instruction $Instruction.TrimEnd() --home $HomePath
if ($LASTEXITCODE -ne 0) { throw 'Instruction removal failed.' }
