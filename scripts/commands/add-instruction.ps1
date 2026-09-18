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
if (-not $PSBoundParameters.ContainsKey('Instruction')) { $Instruction = Read-Host 'Instruction' }
if ([string]::IsNullOrWhiteSpace($Instruction) -or $Instruction.Length -gt 65536) { throw 'Instruction must contain between 1 and 65536 characters.' }
if (-not [System.IO.Path]::IsPathRooted($HomePath)) { throw 'HomePath must be absolute.' }

$directory = Join-Path $HomePath '.my-ai-configuration/instructions'
New-Item -ItemType Directory -Path $directory -Force | Out-Null
foreach ($target in $(if ($Client -eq 'Both') { @('codex','claude') } else { @($Client.ToLowerInvariant()) })) {
    $path = Join-Path $directory "$target.md"
    $prefix = if ((Test-Path -LiteralPath $path) -and (Get-Item -LiteralPath $path).Length -gt 0 -and -not (Get-Content -LiteralPath $path -Raw).EndsWith([Environment]::NewLine)) { [Environment]::NewLine } else { '' }
    [System.IO.File]::AppendAllText($path, $prefix + $Instruction.TrimEnd() + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
    Write-Output "Instruction added for $target."
}
