[CmdletBinding()]
param([switch]$Summary)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'lib/manifest.ps1')
. (Join-Path $PSScriptRoot 'lib/install-targets.ps1')

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("ai-config-install-guard-test-" + [Guid]::NewGuid())
try {
    $installed = Join-Path $work 'installed'
    $missing = Join-Path $work 'missing'
    New-Item $installed -ItemType Directory -Force | Out-Null
    New-Item (Get-ManagedManifestPath $installed) -ItemType File -Force | Out-Null

    if (-not (Test-AnyManifestPresent @($installed, $missing))) { throw 'Expected an installed destination to be detected.' }
    if (Test-AnyManifestPresent @($missing)) { throw 'A destination without a manifest must not count as installed.' }
    if (Test-AllManifestsPresent @($installed, $missing)) { throw 'Update guard must fail when any selected destination is not installed.' }
    if (-not (Test-AllManifestsPresent @($installed))) { throw 'Update guard must pass when every selected destination is installed.' }

    if ($Summary) { Write-Output 'Tests: PASS | install guards' } else { Write-Output 'PASS install guards: already-installed and not-installed detection' }
} finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
exit 0
