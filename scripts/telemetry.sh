#!/usr/bin/env bash
set -euo pipefail
[ "${AI_CONFIG_TELEMETRY:-1}" = 0 ] && exit 0
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd); dir="$root/.ai-session"; path="$dir/telemetry.jsonl"; mkdir -p "$dir"
action=${1:-record}; shift || true
case "$action" in
  rotate) [ -f "$path" ] && mv -f "$path" "$path.1"; exit 0;;
  summary) [ -f "$path" ] || { printf 'Telemetry: no events\n'; exit 0; }; python3 - "$path" <<'PY' || exit 0
import json,sys,statistics
rows=[]
for line in open(sys.argv[1],encoding='utf-8',errors='replace'):
  try: rows.append(json.loads(line))
  except Exception: pass
print(f'Telemetry: {len(rows)} events')
for role in sorted({r.get('role') for r in rows if r.get('role')}):
  subset=[r for r in rows if r.get('role')==role]
  inputs=[r['tokenUsage']['input'] for r in subset if isinstance(r.get('tokenUsage'),dict) and isinstance(r['tokenUsage'].get('input'),(int,float))]
  print(f"{role}: runs {len(subset)} findings {sum(r.get('outcome')=='findings' for r in subset)} median input {int(statistics.median(inputs)) if inputs else '-'}")
PY
    exit 0;;
  record) event=${1:?event required}; shift;; *) printf 'Unknown action: %s\n' "$action" >&2; exit 1;;
esac
python3 - "$path" "$event" "$@" <<'PY' || exit 0
import json,sys,datetime
path,event=sys.argv[1:3]; args=sys.argv[3:]
record={'event':event,'timestamp':datetime.datetime.now(datetime.timezone.utc).isoformat()}
keys=['role','durationMs','handoffBytes','filesRead','filesChanged','outcome','input','cached','output','reasoning']
if any(a.startswith('--') for a in args):
  parsed={}; i=0
  while i < len(args):
    if args[i].startswith('--') and i+1 < len(args): parsed[args[i][2:]]=args[i+1]; i+=2
    else: i+=1
  args=[parsed.get(k,'') for k in keys]
for key,value in zip(keys,args):
  if value: record[key]=int(value) if value.lstrip('-').isdigit() else value
tokens={k:record.pop(k) for k in ('input','cached','output','reasoning') if k in record}
if tokens: record['tokenUsage']=tokens
with open(path,'a',encoding='utf-8') as out: out.write(json.dumps(record,separators=(',',':'))+'\n')
PY
if [ "$(wc -c < "$path")" -gt 1048576 ]; then mv -f "$path" "$path.1"; fi
