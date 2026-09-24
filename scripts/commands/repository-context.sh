#!/usr/bin/env bash
set -euo pipefail
force=false; summary=false
for arg in "$@"; do case "$arg" in --force) force=true;; --summary) summary=true;; *) printf 'Unknown argument: %s\n' "$arg" >&2; exit 1;; esac; done
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd); cache_dir="$root/.ai-session"; cache_path="$cache_dir/repository-context.json"
head=$(git -c "safe.directory=$root" -C "$root" rev-parse HEAD 2>/dev/null || true); key_input=$head
while IFS= read -r file; do key_input+="\n$file:$(sha256sum "$file" | awk '{print $1}')"; done < <(find "$root" -type f \( -name AI-Instructions.md -o -path '*/adapters/*' -o -path '*/shared/*' -o -path '*/scripts/*' \) ! -path '*/generated/*' ! -path '*/.git/*' ! -path '*/.ai-session/*' ! -path '*/__pycache__/*' | sort)
key=$(printf '%s' "$key_input" | sha256sum | awk '{print $1}')
if [ "$force" = false ] && [ -f "$cache_path" ] && grep -Fq "\"invalidationKey\": \"$key\"" "$cache_path"; then [ "$summary" = true ] && printf 'Repository context: unchanged\n'; exit 0; fi
mapfile -t languages < <(find "$root" -type f ! -path '*/generated/*' ! -path '*/.git/*' ! -path '*/node_modules/*' ! -path '*/.ai-session/*' | awk -F. 'NF>1 {print $NF}' | sort -u | awk 'BEGIN{a["cs"]="csharp";a["ts"]="typescript";a["tsx"]="typescript";a["py"]="python";a["ps1"]="powershell";a["sh"]="bash"} a[$1]!=""{print a[$1]}' | sort -u)
solutions=$(find "$root" -type f -name '*.sln' ! -path '*/generated/*' -printf '"%f",' | sed 's/,$//'); tests=$(find "$root" -type f ! -path '*/generated/*' ! -path '*/.git/*' -iname '*test*' -printf '"%f",' | sed 's/,$//'); manager=null; [ -f "$root/pnpm-lock.yaml" ] && manager='"pnpm"'; [ -f "$root/package-lock.json" ] && manager='"npm"'; [ -f "$root/yarn.lock" ] && manager='"yarn"'
mkdir -p "$cache_dir"; printf '{\n  "invalidationKey": "%s",\n  "head": "%s",\n  "languages": [%s],\n  "frameworks": [],\n  "solutions": [%s],\n  "testProjects": [%s],\n  "packageManager": %s,\n  "buildCommands": {}\n}\n' "$key" "$head" "$(printf '"%s",' "${languages[@]}" | sed 's/,$//')" "$solutions" "$tests" "$manager" > "$cache_path"
if [ "$summary" = true ]; then printf 'Repository context: refreshed | %s languages | %s solutions\n' "${#languages[@]}" "$(find "$root" -type f -name '*.sln' ! -path '*/generated/*' | wc -l)"; else printf '%s\n' "$cache_path"; fi
