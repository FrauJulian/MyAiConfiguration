#!/usr/bin/env bash
set -euo pipefail
summary=false
for arg in "$@"; do case "$arg" in --summary) summary=true;; *) printf 'Unknown argument: %s\n' "$arg" >&2; exit 1;; esac; done
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
generated="$root/generated"
[ -f "$generated/claude-linux/CLAUDE.md" ] || { printf 'Generated output is missing; run build first.\n' >&2; exit 1; }
bytes() { wc -c < "$1" | tr -d ' '; }
tree_bytes() { find "$1" -type f -printf '%s\n' 2>/dev/null | awk '{s+=$1} END {print s+0}'; }
tokens() { awk -v b="$1" 'BEGIN { printf "%d", (b + 3) / 4 }'; }
claude=$(bytes "$generated/claude-linux/CLAUDE.md"); codex=$(bytes "$generated/codex-linux/AGENTS.md"); skills=$(tree_bytes "$generated/claude-linux/skills"); triggers=$(bytes "$root/adapters/claude/rule-skills.tsv"); lazy=$(find "$root/shared/rules" -type f -printf '%s %p\n' | sort -nr | awk 'NR==1 {print $1+0}'); fail=false
if [ -f "$root/adapters/prompt-budget-baseline.tsv" ]; then while IFS=$'\t' read -r name old; do current=$([ "$name" = Claude ] && printf '%s' "$claude" || printf '%s' "$codex"); awk -v n="$current" -v o="$old" 'BEGIN { exit !(o > 0 && n > o * 1.15) }' && fail=true; done < "$root/adapters/prompt-budget-baseline.tsv"; fi
if [ "$summary" = true ]; then printf 'Prompt Budget\nClaude permanent context    %8s bytes  %6s tokens\nCodex permanent context     %8s bytes  %6s tokens\nClaude skill metadata       %8s bytes  %6s tokens\nRule trigger metadata       %8s bytes  %6s tokens\nLargest lazy rule           %8s bytes  %6s tokens\n' "$claude" "$(tokens "$claude")" "$codex" "$(tokens "$codex")" "$skills" "$(tokens "$skills")" "$triggers" "$(tokens "$triggers")" "$lazy" "$(tokens "$lazy")"; else printf 'Prompt budget: Claude %s bytes, Codex %s bytes, skills %s bytes, triggers %s bytes, largest lazy rule %s bytes\n' "$claude" "$codex" "$skills" "$triggers" "$lazy"; fi
$fail && { printf 'Prompt budget: permanent context increased by more than 15 percent.\n' >&2; exit 1; }
