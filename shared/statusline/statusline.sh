#!/usr/bin/env bash
set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0
input=
while IFS= read -r line || [ -n "$line" ]; do input+="$line"; done
IFS=$'\t' read -r model effort repo directory max_context used_context used_tokens < <(
  printf '%s' "$input" | jq -r '[
    (.model.display_name // "-"),
    (.effort.level // "-"),
    (.workspace.repo.name // "-"),
    (.workspace.current_dir // .cwd // "."),
    (.context_window.context_window_size // 0),
    (if .context_window.used_percentage == null then "-" else ((.context_window.used_percentage | round | tostring) + "%") end),
    ((.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0))
  ] | @tsv'
)
[ "$repo" != - ] || repo=$(basename -- "$directory")
[ -n "$repo" ] || repo=-
branch=$(git -C "$directory" branch --show-current 2>/dev/null || true)
[ -n "$branch" ] || branch=-
printf 'Model: %s | Effort: %s | Repo: %s | Branch: %s | Max Context: %s | Used Context: %s | Used Tokens: %s\n' "$model" "$effort" "$repo" "$branch" "$max_context" "$used_context" "$used_tokens"
