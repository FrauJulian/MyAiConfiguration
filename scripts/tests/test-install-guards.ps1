[CmdletBinding()]
param([switch]$Summary)
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $root 'scripts/lib/manifest.ps1')
. (Join-Path $root 'scripts/lib/install-targets.ps1')

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

    # QMD prompt: Auto maps device suitability; No never calls the benchmark.
    . (Join-Path $root 'scripts/lib/install-options.ps1')
    $originalIn = [Console]::In
    try {
        function Test-QmdDevice { param($RepositoryRoot, $HomePath) return $false }
        [Console]::SetIn([IO.StringReader]::new("a`n"))
        if ((Read-SemanticRetrievalOption -Default $false -RepositoryRoot $root -HomePath $work) -ne $false) { throw 'Auto unsuitable must yield false' }
        function Test-QmdDevice { param($RepositoryRoot, $HomePath) return $true }
        [Console]::SetIn([IO.StringReader]::new("a`n"))
        if ((Read-SemanticRetrievalOption -Default $false -RepositoryRoot $root -HomePath $work) -ne $true) { throw 'Auto suitable must yield true' }
        function Test-QmdDevice { throw 'must not run' }
        [Console]::SetIn([IO.StringReader]::new("n`n"))
        if ((Read-SemanticRetrievalOption -Default $true -RepositoryRoot $root -HomePath $work) -ne $false) { throw 'No must yield false' }
    } finally { [Console]::SetIn($originalIn) }
    if ((Get-Content -Raw (Join-Path $root 'scripts/lib/install-options.ps1')) -notmatch 'Enable local QMD search models \(Qwen3 embedding, Qwen3 reranker, QMD query expansion\)\? \[') { throw 'prompt text changed' }

    if ($Summary) { Write-Output 'Tests: PASS | install guards' } else { Write-Output 'PASS install guards: already-installed and not-installed detection' }
} finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
exit 0
