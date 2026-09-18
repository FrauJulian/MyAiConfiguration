#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
arguments=()
if [ "${AI_TASK_GOAL+x}" = x ]; then arguments+=(--goal "$AI_TASK_GOAL"); fi
python3 "$root/shared/hooks/scripts/session-state.py" "${arguments[@]}" "$@"
