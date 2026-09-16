#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
[ -f "$root/.ai-session/state.json" ] && printf 'Task state is available in .ai-session/state.json; read it only if needed.\n'
