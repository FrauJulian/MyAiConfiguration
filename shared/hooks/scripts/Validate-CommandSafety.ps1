param([Parameter(Mandatory=$true)][string]$Command, [string]$Workspace = (Get-Location).Path)
$dangerous = @('git reset --hard','git clean -fd','git clean -fx','Remove-Item -Recurse','rm -rf','format c:','del /s /q')
foreach ($pattern in $dangerous) { if ($Command.IndexOf($pattern, [StringComparison]::OrdinalIgnoreCase) -ge 0) { Write-Error "Blocked potentially destructive command: $pattern"; exit 1 } }
if ($Command -match '(?i)(^|\s)([A-Z]:\\|/)(?!.*' + [regex]::Escape($Workspace) + ')') { Write-Error 'Blocked command containing an absolute path outside the workspace.'; exit 1 }
Write-Output 'PASS command safety'
