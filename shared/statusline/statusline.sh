#!/usr/bin/env bash
set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0
input=
while IFS= read -r line || [ -n "$line" ]; do input+="$line"; done
IFS=$'\t' read -r model effort repo directory used_percentage used_tokens < <(
  printf '%s' "$input" | jq -r '[
    (.model.display_name // "-"),
    (.effort.level // "-"),
    (.workspace.repo.name // "-"),
    (.workspace.current_dir // .cwd // "."),
    (if .context_window.used_percentage == null then "-" else (.context_window.used_percentage | round) end),
    ((.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0))
  ] | @tsv'
)
used_percentage=${used_percentage%$'\r'}
used_tokens=${used_tokens%$'\r'}
[ "$repo" != - ] || repo=$(basename -- "$directory")
[ -n "$repo" ] || repo=-
branch=$(git -C "$directory" branch --show-current 2>/dev/null || true)
[ -n "$branch" ] || branch=-

if [ "$used_percentage" != - ]; then
  used_context="${used_percentage}%"
else
  used_context=-
fi
if [ "$used_tokens" -ge 1000 ]; then
  used_tokens_display=$(awk -v t="$used_tokens" 'BEGIN { printf "%.1fk", t / 1000 }')
else
  used_tokens_display=$used_tokens
fi

esc=$'\033'
reset="$esc[0m"
dim="$esc[90m"
cyan="$esc[36m"
magenta="$esc[35m"
blue="$esc[34m"
green="$esc[32m"
if [ "$used_percentage" = - ]; then
  context_color=$dim
elif [ "$used_percentage" -ge 85 ]; then
  context_color="$esc[31m"
elif [ "$used_percentage" -ge 60 ]; then
  context_color="$esc[33m"
else
  context_color=$green
fi
sep="${dim}·${reset}"

printf "${cyan}%s${reset} ${sep} ${magenta}%s${reset}\n${blue}%s${reset}${dim} on${reset} ${green}%s${reset}  ${sep}  ${context_color}%s ctx${reset} ${dim}(%s tok)${reset}\n" \
  "$model" "$effort" "$repo" "$branch" "$used_context" "$used_tokens_display"
