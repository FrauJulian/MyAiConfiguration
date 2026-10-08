// Background warm-up started by the SessionStart hook; never fails the session.
import { execFileSync } from 'node:child_process';
import { appendFileSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';
import { collectionName, readJson, stateDir } from './qmd-lib.mjs';
import { startDaemon } from './qmd-search.mjs';

const STALE_MS = 30 * 60_000;

export async function withLock(lockPath, fn, now = Date.now) {
  try {
    writeFileSync(lockPath, String(now()), { flag: 'wx' });
  } catch {
    const age = now() - Number(readFileSync(lockPath, 'utf8'));
    if (!(age > STALE_MS)) return false;
    writeFileSync(lockPath, String(now()));
  }
  try {
    await fn();
    return true;
  } finally {
    rmSync(lockPath, { force: true });
  }
}

async function refresh(root) {
  const info = readJson(join(stateDir(), 'daemon.json'), null);
  if (!info?.port) throw new Error('daemon not running');
  const response = await fetch(`http://127.0.0.1:${info.port}/refresh`, { method: 'POST',
    headers: { 'x-qmd-token': info.token, 'content-type': 'application/json' }, body: JSON.stringify({ repo: root }),
    signal: AbortSignal.timeout(35 * 60_000) });
  if (!response.ok) throw new Error(`refresh answered ${response.status}`);
}

async function main() {
  const { values } = parseArgs({ options: { root: { type: 'string' } } });
  const root = resolve(values.root || execFileSync('git', ['rev-parse', '--show-toplevel'], { encoding: 'utf8' }).trim());
  const dir = stateDir();
  mkdirSync(dir, { recursive: true });
  // A refresh through the daemon indexes the repository incrementally; start the daemon first if needed.
  await withLock(join(dir, `${collectionName(root)}.lock`), async () => {
    try {
      await refresh(root);
    } catch {
      try { await startDaemon(); } catch { /* another daemon may have won the start race */ }
      await refresh(root);
    }
  });
}

if (import.meta.url === pathToFileURL(process.argv[1] || '').href) {
  main().catch((error) => {
    try { appendFileSync(join(stateDir(), 'warm.log'), `${new Date().toISOString()} ${error.message}\n`); } catch { /* ignore */ }
  }).finally(() => process.exit(0));
}
