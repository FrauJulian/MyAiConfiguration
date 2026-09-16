[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$invariantCulture = [System.Globalization.CultureInfo]::InvariantCulture
$data = ($input | Out-String) | ConvertFrom-Json
$model = if ($data.model.display_name) { $data.model.display_name } else { '-' }
$effort = if ($data.effort.level) { $data.effort.level } else { '-' }
$directory = if ($data.workspace.current_dir) { $data.workspace.current_dir } else { $data.cwd }
$repo = if ($data.workspace.repo.name) { $data.workspace.repo.name } elseif ($directory) { Split-Path $directory -Leaf } else { '-' }
$branch = if ($directory -and (Get-Command git -ErrorAction SilentlyContinue)) { (& git -C $directory branch --show-current 2>$null | Select-Object -First 1) } else { $null }
if (-not $branch) { $branch = '-' }
$usedPercentage = if ($null -ne $data.context_window.used_percentage) { [double]$data.context_window.used_percentage } else { $null }
$usedContext = if ($null -ne $usedPercentage) { "$([math]::Round($usedPercentage, [MidpointRounding]::AwayFromZero).ToString($invariantCulture))%" } else { '-' }
$usedTokens = [long]$data.context_window.total_input_tokens + [long]$data.context_window.total_output_tokens
$usedTokensDisplay = if ($usedTokens -ge 1000) { ($usedTokens / 1000).ToString('0.0', $invariantCulture) + 'k' } else { $usedTokens.ToString($invariantCulture) }

$esc = [char]27
$reset = "$esc[0m"
$dim = "$esc[90m"
$cyan = "$esc[36m"
$magenta = "$esc[35m"
$blue = "$esc[34m"
$green = "$esc[32m"
$contextColor = if ($null -eq $usedPercentage) { $dim } elseif ($usedPercentage -ge 85) { "$esc[31m" } elseif ($usedPercentage -ge 60) { "$esc[33m" } else { $green }
$middot = [char]0x00B7
$sep = "$dim$middot$reset"

$line1 = "$cyan$model$reset $sep $magenta$effort$reset"
$line2 = "$blue$repo$reset$dim on$reset $green$branch$reset  $sep  $contextColor$usedContext ctx$reset $dim($usedTokensDisplay tok)$reset"
Write-Output "$line1`n$line2"
