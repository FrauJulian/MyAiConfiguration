#!/usr/bin/env bash
set -uo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
python3 "$script_dir/session-state.py" --hook 2>/dev/null || true
