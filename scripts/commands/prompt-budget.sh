#!/usr/bin/env bash
set -euo pipefail
summary=false
for arg in "$@"; do case "$arg" in --summary) summary=true;; *) printf 'Unknown argument: %s\n' "$arg" >&2; exit 1;; esac; done
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
generated="$root/generated"
[ -f "$generated/claude-bash/CLAUDE.md" ] || { printf 'Generated output is missing; run build first.\n' >&2; exit 1; }
bytes() { wc -c < "$1" | tr -d ' '; }
tree_bytes() { find "$1" -type f -printf '%s\n' 2>/dev/null | awk '{s+=$1} END {print s+0}'; }
tokens() { awk -v b="$1" 'BEGIN { printf "%d", (b + 3) / 4 }'; }
claude=$(bytes "$generated/claude-bash/CLAUDE.md"); codex=$(bytes "$generated/codex-bash/AGENTS.md"); skills=$(tree_bytes "$generated/claude-bash/skills"); lazy=$(find "$root/shared/rules" -type f -printf '%s %p\n' | sort -nr | awk 'NR==1 {print $1+0}'); fail=false
claude_baseline=0; codex_baseline=0; claude_absolute=0; codex_absolute=0
if [ -f "$root/adapters/prompt-budget-baseline.tsv" ]; then
  while IFS=$'\t' read -r name old absolute; do
    [ "$name" = Claude ] || [ "$name" = Codex ] || continue
    current=$([ "$name" = Claude ] && printf '%s' "$claude" || printf '%s' "$codex")
    [ "$name" = Claude ] && claude_baseline=$old && claude_absolute=$absolute
    [ "$name" = Codex ] && codex_baseline=$old && codex_absolute=$absolute
    if awk -v n="$current" -v o="$old" 'BEGIN { exit !(o > 0 && n > o * 1.15) }'; then printf 'Prompt budget soft target exceeded: %s %s bytes (target %s, 15%% tolerance).\n' "$name" "$current" "$old" >&2; fi
    if awk -v n="$current" -v a="$absolute" 'BEGIN { exit !(a > 0 && n > a) }'; then printf 'Prompt budget hard limit failed: %s %s bytes (hard limit %s).\n' "$name" "$current" "$absolute" >&2; fail=true; fi
  done < "$root/adapters/prompt-budget-baseline.tsv"
fi
if [ "$summary" = true ]; then printf 'Prompt Budget\nClaude permanent context    %8s bytes  soft target %s  hard limit %s\nCodex permanent context     %8s bytes  soft target %s  hard limit %s\nClaude skill files (lazy)       %8s bytes  %6s tokens\nLargest lazy rule           %8s bytes  %6s tokens\n' "$claude" "$claude_baseline" "$claude_absolute" "$codex" "$codex_baseline" "$codex_absolute" "$skills" "$(tokens "$skills")" "$lazy" "$(tokens "$lazy")"; else printf 'Prompt budget: Claude %s bytes, Codex %s bytes, skills %s bytes, largest lazy rule %s bytes\n' "$claude" "$codex" "$skills" "$lazy"; fi
python3 "$root/scripts/lib/prompt-inventory.py" --home "${HOME:?HOME is required}"
$fail && { printf 'Prompt budget: permanent context exceeded hard limit.\n' >&2; exit 1; }
exit 0
