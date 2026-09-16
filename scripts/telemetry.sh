#!/usr/bin/env bash
set -euo pipefail
[ "${AI_CONFIG_TELEMETRY:-1}" = 0 ] && exit 0
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd); dir="$root/.ai-session"; path="$dir/telemetry.jsonl"; mkdir -p "$dir"
case "${1:-record}" in
  rotate) [ -f "$path" ] && mv -f "$path" "$path.1"; exit 0;;
  summary) [ -f "$path" ] || { printf 'Telemetry: no events\n'; exit 0; }; count=$(wc -l < "$path" | tr -d ' '); agents=$(grep -c '"event":"subagent-stop"' "$path" || true); printf 'Telemetry: %s events | %s subagents\n' "$count" "$agents"; exit 0;;
  record) event=${2:?event required};; *) printf 'Unknown action: %s\n' "$1" >&2; exit 1;;
esac
printf '{"event":"%s","timestamp":"%s"}\n' "$event" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$path"; [ "$(wc -c < "$path")" -le 1048576 ] || mv -f "$path" "$path.1"
