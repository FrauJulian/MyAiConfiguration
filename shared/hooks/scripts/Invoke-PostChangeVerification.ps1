param([string]$RepositoryRoot = (Split-Path $PSScriptRoot -Parent | Split-Path -Parent | Split-Path -Parent))
$build = Join-Path $RepositoryRoot 'scripts/build.ps1'
if (-not (Test-Path $build)) { Write-Error 'Build script is missing.'; exit 1 }
$shellCommand = if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { 'powershell' } else { 'pwsh' }
& $shellCommand -NoProfile -ExecutionPolicy Bypass -File $build
if ($LASTEXITCODE) { exit $LASTEXITCODE }
Write-Output 'PASS post-change verification'
