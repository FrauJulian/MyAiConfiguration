$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
& python (Join-Path $root 'scripts/benchmarks/ab.py') @args
exit $LASTEXITCODE
