# SessionStart: warm the QMD index and daemon in the background; never blocks or fails the session.
$ErrorActionPreference = 'SilentlyContinue'
$script = Join-Path $HOME '.my-ai-configuration/qmd/qmd-warm.mjs'
$node = Get-Command node -ErrorAction SilentlyContinue
if ((Test-Path -LiteralPath $script) -and $node) {
    $null = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0) {
        Start-Process -FilePath $node.Source -ArgumentList @("`"$script`"") -WindowStyle Hidden -WorkingDirectory (Get-Location).Path
    }
}
exit 0
