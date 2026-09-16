#!/usr/bin/env bash
set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0
input=
while IFS= read -r line || [ -n "$line" ]; do input+="$line"; done
IFS=$'\t' read -r model effort repo directory used_percentage used_tokens context_window < <(
  printf '%s' "$input" | jq -r '[
    (.model.display_name // "-"),
    (.effort.level // "-"),
    (.workspace.repo.name // "-"),
    (.workspace.current_dir // .cwd // "-"),
    (if .context_window.used_percentage == null then "-" else (.context_window.used_percentage | round) end),
    ((.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0)),
    (.context_window.context_window_size // "-")
  ] | @tsv'
)
used_percentage=${used_percentage%$'\r'}
used_tokens=${used_tokens%$'\r'}
context_window=${context_window%$'\r'}
if [ "$repo" = - ]; then
  repo_root=$(git -C "$directory" rev-parse --show-toplevel 2>/dev/null || true)
  repo=$(basename -- "${repo_root:-$directory}")
fi
[ -n "$repo" ] || repo=-
branch=$(git -C "$directory" branch --show-current 2>/dev/null || true)
[ -n "$branch" ] || branch=-

if [ "$used_percentage" != - ]; then
  used_context="${used_percentage}%"
else
  used_context=-
fi
format_token_count() {
  LC_ALL=C awk -v t="$1" 'BEGIN {
    if (t == "-") { printf "-"; exit }
    suffix = ""
    if (t >= 1000000) { t /= 1000000; suffix = "M" }
    else if (t >= 1000) { t /= 1000; suffix = "k" }
    value = sprintf("%.1f", t)
    sub(/\.0$/, "", value)
    printf "%s%s", value, suffix
  }'
}
used_tokens_display=$(format_token_count "$used_tokens")
context_window_display=$(format_token_count "$context_window")

esc=$'\033'
reset="$esc[0m"
dim="$esc[90m"
cyan="$esc[96m"
magenta="$esc[95m"
blue="$esc[94m"
green="$esc[92m"
if [ "$used_percentage" = - ]; then
  context_color=$dim
elif [ "$used_percentage" -ge 85 ]; then
  context_color="$esc[31m"
elif [ "$used_percentage" -ge 60 ]; then
  context_color="$esc[33m"
else
  context_color=$green
fi
if [ -n "${NO_COLOR:-}" ]; then
  reset= dim= cyan= magenta= blue= green= context_color=
fi
sep="${dim}·${reset}"

printf "${cyan}%s${reset} ${sep} Effort ${magenta}%s${reset} ${sep} ${blue}%s${reset} @ ${green}%s${reset}\nCtx ${cyan}%s${reset} ${sep} Used ${context_color}%s${reset} ${sep} Tokens ${magenta}%s${reset}\n" \
  "$model" "$effort" "$repo" "$branch" "$context_window_display" "$used_context" "$used_tokens_display"
