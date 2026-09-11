$data = ($input | Out-String) | ConvertFrom-Json
$model = if ($data.model.display_name) { $data.model.display_name } else { '-' }
$effort = if ($data.effort.level) { $data.effort.level } else { '-' }
$directory = if ($data.workspace.current_dir) { $data.workspace.current_dir } else { $data.cwd }
$repo = if ($data.workspace.repo.name) { $data.workspace.repo.name } elseif ($directory) { Split-Path $directory -Leaf } else { '-' }
$branch = if ($directory -and (Get-Command git -ErrorAction SilentlyContinue)) { (& git -C $directory branch --show-current 2>$null | Select-Object -First 1) } else { $null }
if (-not $branch) { $branch = '-' }
$maxContext = if ($data.context_window.context_window_size) { [long]$data.context_window.context_window_size } else { 0 }
$usedContext = if ($null -ne $data.context_window.used_percentage) { "$([math]::Round([double]$data.context_window.used_percentage, [MidpointRounding]::AwayFromZero))%" } else { '-' }
$usedTokens = [long]$data.context_window.total_input_tokens + [long]$data.context_window.total_output_tokens
Write-Output "Model: $model | Effort: $effort | Repo: $repo | Branch: $branch | Max Context: $maxContext | Used Context: $usedContext | Used Tokens: $usedTokens"
