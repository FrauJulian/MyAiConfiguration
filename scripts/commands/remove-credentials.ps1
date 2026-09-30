[CmdletBinding()]
param(
    [ValidateSet('Codex','Claude','Both')][string]$Client,
    [string]$Key
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
if (-not $Key) { $Key = Read-Host 'Credential key to remove' }
Assert-CredentialKey $Key

foreach ($target in $(if ($Client -eq 'Both') { @('Codex', 'Claude') } else { @($Client) })) {
    try {
        Remove-ManagedCredential $target $Key
        Write-Output "Credential removed for $($target.ToLowerInvariant())."
    } catch [ComponentModel.Win32Exception] {
        if ($_.Exception.NativeErrorCode -ne 1168) { throw }
        Write-Output "Credential not found for $($target.ToLowerInvariant())."
    }
}
