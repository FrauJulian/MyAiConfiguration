#!/usr/bin/env bash
set -euo pipefail

root=${1:?Repository root is required}
bash "$root/scripts/build.sh"
printf 'PASS post-change verification\n'
