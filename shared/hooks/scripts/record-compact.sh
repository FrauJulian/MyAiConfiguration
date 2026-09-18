#!/usr/bin/env bash
set -uo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
[ "${AI_CONFIG_TELEMETRY:-1}" = 0 ] || { mkdir -p "$root/.ai-session" && printf '{"event":"compact","timestamp":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$root/.ai-session/telemetry.jsonl"; [ "$(wc -c < "$root/.ai-session/telemetry.jsonl")" -le 1048576 ] || mv -f "$root/.ai-session/telemetry.jsonl" "$root/.ai-session/telemetry.jsonl.1"; }
python3 "$root/hooks/scripts/session-state.py" --hook 2>/dev/null || true
