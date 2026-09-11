#!/usr/bin/env bash
set -euo pipefail

command_text=${1:?Command is required}
workspace=${2:-$PWD}
for pattern in 'git reset --hard' 'git clean -fd' 'git clean -fx' 'rm -rf' 'Remove-Item -Recurse' 'format c:' 'del /s /q'; do
  [[ ${command_text,,} != *"${pattern,,}"* ]] || { printf 'Blocked potentially destructive command: %s\n' "$pattern" >&2; exit 1; }
done
printf 'PASS command safety\n'
