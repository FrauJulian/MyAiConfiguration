#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
mkdir -p "$root/.ai-session"
printf '{"event":"compact","timestamp":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$root/.ai-session/telemetry.jsonl"
python3 "$root/hooks/scripts/session-state.py" --hook
