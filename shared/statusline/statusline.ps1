[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$invariantCulture = [System.Globalization.CultureInfo]::InvariantCulture
function Format-TokenCount {
    param($Value)
    if ($null -eq $Value) { return '-' }
    $count = [double]$Value
    if ($count -ge 1000000) { return ($count / 1000000).ToString('0.#', $invariantCulture) + 'M' }
    if ($count -ge 1000) { return ($count / 1000).ToString('0.#', $invariantCulture) + 'k' }
    return $count.ToString('0', $invariantCulture)
}
$data = ($input | Out-String) | ConvertFrom-Json
$model = if ($data.model.display_name) { $data.model.display_name } else { '-' }
$effort = if ($data.effort.level) { $data.effort.level } else { '-' }
$directory = if ($data.workspace.current_dir) { $data.workspace.current_dir } else { $data.cwd }
$repo = if ($data.workspace.repo.name) { $data.workspace.repo.name } elseif ($directory) { Split-Path $directory -Leaf } else { '-' }
if (-not $data.workspace.repo.name -and $directory -and (Get-Command git -ErrorAction SilentlyContinue)) {
    $repoRoot = & git -C $directory rev-parse --show-toplevel 2>$null | Select-Object -First 1
    if ($repoRoot) { $repo = Split-Path $repoRoot -Leaf }
}
$branch = if ($directory -and (Get-Command git -ErrorAction SilentlyContinue)) { (& git -C $directory branch --show-current 2>$null | Select-Object -First 1) } else { $null }
if (-not $branch) { $branch = '-' }
$usedPercentage = if ($null -ne $data.context_window.used_percentage) { [math]::Round([double]$data.context_window.used_percentage, [MidpointRounding]::AwayFromZero) } else { $null }
$usedContext = if ($null -ne $usedPercentage) { "$([math]::Round($usedPercentage, [MidpointRounding]::AwayFromZero).ToString($invariantCulture))%" } else { '-' }
$usedTokens = [long]$data.context_window.total_input_tokens + [long]$data.context_window.total_output_tokens
$usedTokensDisplay = Format-TokenCount $usedTokens
$contextWindow = Format-TokenCount $data.context_window.context_window_size

$esc = [char]27
$reset = "$esc[0m"
$dim = "$esc[90m"
$cyan = "$esc[96m"
$magenta = "$esc[95m"
$blue = "$esc[94m"
$green = "$esc[92m"
$contextColor = if ($null -eq $usedPercentage) { $dim } elseif ($usedPercentage -ge 85) { "$esc[31m" } elseif ($usedPercentage -ge 60) { "$esc[33m" } else { $green }
$middot = [char]0x00B7
$sep = "$dim$middot$reset"

$line1 = "$cyan$model$reset $sep Effort $magenta$effort$reset $sep $blue$repo$reset @ $green$branch$reset"
$line2 = "Ctx $cyan$contextWindow$reset $sep Used $contextColor$usedContext$reset $sep Tokens $magenta$usedTokensDisplay$reset"
$outputText = "$line1`n$line2"
if ($env:NO_COLOR) { $outputText = [regex]::Replace($outputText, [char]27 + '\[[0-9;]*m', '') }
Write-Output $outputText
