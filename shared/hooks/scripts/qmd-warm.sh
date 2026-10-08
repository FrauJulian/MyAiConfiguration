#!/usr/bin/env bash
# SessionStart: warm the QMD index and daemon in the background; never blocks or fails the session.
script="$HOME/.my-ai-configuration/qmd/qmd-warm.mjs"
if [ -f "$script" ] && command -v node >/dev/null 2>&1 && git rev-parse --show-toplevel >/dev/null 2>&1; then
  nohup node "$script" >/dev/null 2>&1 &
fi
exit 0
