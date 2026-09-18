[CmdletBinding()]
param(
    [ValidateSet('Codex', 'Claude', 'Both')][string]$Client,
    [string]$Key,
    [switch]$ValueFromStdin,
    [string]$HomePath = [Environment]::GetFolderPath('UserProfile')
)
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $root 'scripts/lib/install-targets.ps1')
$selectedClient = $Client
$selectedKey = $Key
. (Join-Path $root 'scripts/lib/credentials.ps1')
$Client = $selectedClient
$Key = $selectedKey

if (-not $Client) { $Client = Read-InstallClient -Client $Client }
if (-not $Key) { $Key = Read-Host 'Credential key' }
Assert-CredentialKey $Key
if (-not [System.IO.Path]::IsPathRooted($HomePath)) { throw 'HomePath must be absolute.' }
if ($ValueFromStdin) {
    $text = [Console]::In.ReadToEnd().TrimEnd("`r", "`n")
    $Value = ConvertTo-SecureString $text -AsPlainText -Force
    $text = $null
} else {
    $Value = Read-Host 'Credential value' -AsSecureString
}

$bin = Join-Path $HomePath '.my-ai-configuration/bin'
New-Item -ItemType Directory -Path $bin -Force | Out-Null
foreach ($source in @('credentials.ps1', 'with-credential.sh')) {
    $destination = Join-Path $bin $(if ($source -eq 'credentials.ps1') { 'with-credential.ps1' } else { $source })
    if (-not (Test-Path -LiteralPath $destination)) { Copy-Item (Join-Path $root "scripts/lib/$source") $destination }
}
foreach ($target in $(if ($Client -eq 'Both') { @('Codex', 'Claude') } else { @($Client) })) {
    Set-ManagedCredential $target $Key $Value
    Write-Output "Credential stored for $($target.ToLowerInvariant())."
}
$Value = $null
