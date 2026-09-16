#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd); dir="$root/.ai-session"; path="$dir/state.json"
if [ "${1:-}" = --pointer ]; then [ -f "$path" ] && printf 'Task state is available in .ai-session/state.json; read it only if needed.\n'; exit 0; fi
goal=${AI_TASK_GOAL:-}; goal=${goal:0:240}; goal_json=$(printf '%s' "$goal" | sed 's/[\\]/\\\\/g; s/"/\\"/g'); mkdir -p "$dir"
printf '{"goal":"%s","changedFiles":[],"verified":[],"pending":[],"importantFindings":[],"updatedAt":"%s"}\n' "$goal_json" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$path"
