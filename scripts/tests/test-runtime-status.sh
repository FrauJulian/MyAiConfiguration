#!/usr/bin/env bash
set -euo pipefail
summary=false
while [ $# -gt 0 ]; do
  case "$1" in
    --summary) summary=true; shift ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
grep -Eq '\$HoldMs[[:space:]]*=[[:space:]]*250' "$root/shared/hooks/flashbang.ps1"
grep -Eq '\$FadeMs[[:space:]]*=[[:space:]]*250' "$root/shared/hooks/flashbang.ps1"
[ "$(grep -c 'default=250' "$root/shared/hooks/flashbang.sh")" -ge 2 ]
branch=$(git -C "$root" branch --show-current)
build_summary_output=$(bash "$root/scripts/commands/build.sh" --summary)
if ! printf '%s\n' "$build_summary_output" | grep -qx 'Build: PASS | 4 packages'; then
  printf 'build.sh --summary must still print the PASS line: %s\n' "$build_summary_output" >&2
  exit 1
fi
[ "$build_summary_output" = 'Build: PASS | 4 packages' ]
status_output=$(printf '{"model":{"display_name":"Test Model"},"effort":{"level":"high"},"workspace":{"current_dir":"%s","repo":{"name":"TestRepo"}},"context_window":{"context_window_size":200000,"used_percentage":8.5,"total_input_tokens":15500,"total_output_tokens":1200}}' "$root" | bash "$root/shared/statusline/statusline.sh")
plain_status_output=$(printf '%s' "$status_output" | sed -E $'s/\x1b\\[[0-9;]*m//g')
expected_status_output=$'Test Model \xc2\xb7 Review auto \xc2\xb7 Effort high \xc2\xb7 TestRepo @ '"$branch"$'\nCtx 200k \xc2\xb7 Used 9% \xc2\xb7 Tokens 16.7k'
[ "$plain_status_output" = "$expected_status_output" ]
if [ "$summary" = true ]; then printf 'Tests: PASS | runtime status\n'; else printf 'PASS build summary and status lines\n'; fi
