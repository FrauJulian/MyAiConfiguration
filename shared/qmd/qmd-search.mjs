// shared/qmd/qmd-search.mjs — search the current repository through the QMD daemon, with a CLI fallback.
import { execFileSync, spawn } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';
import { collectionName, deviceEnv, readJson, runQmdCli, setupStatePath, stateDir } from './qmd-lib.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const daemonFile = () => join(stateDir(), 'daemon.json');

export function toCliResults(items, collection) {
  return items.map((item) => {
    const prefix = `qmd://${collection}/`;
    const path = String(item.file || '').startsWith(prefix) ? item.file.slice(prefix.length) : item.file;
    return { path, line: item.line ?? null, score: item.score, snippet: item.snippet ?? '' };
  });
}

async function callDaemon(path, body) {
  const info = readJson(daemonFile(), null);
  if (!info?.port || !info?.token) throw new Error('daemon not running');
  const response = await fetch(`http://127.0.0.1:${info.port}${path}`, {
    method: 'POST', headers: { 'x-qmd-token': info.token, 'content-type': 'application/json' },
    body: JSON.stringify(body), signal: AbortSignal.timeout(600_000) });
  if (!response.ok) throw new Error(`daemon answered ${response.status}`);
  return response.json();
}

export async function startDaemon() {
  const device = readJson(setupStatePath(), {}).device || 'cpu';
  const child = spawn(process.execPath, [join(here, 'qmd-daemon.mjs')], { detached: true, stdio: 'ignore', windowsHide: true, env: deviceEnv(device) });
  child.unref();
  const deadline = Date.now() + 120_000;
  while (Date.now() < deadline) {
    await new Promise((done) => setTimeout(done, 500));
    const info = readJson(daemonFile(), null);
    if (info?.port && info?.token && info.pid === child.pid) return;
  }
  throw new Error('daemon did not start within 120 s');
}

function runCli(args) {
  const device = readJson(setupStatePath(), {}).device || 'cpu';
  return JSON.parse(runQmdCli(args, { env: deviceEnv(device), windowsHide: true }));
}

export async function runSearch({ root, query, topK, daemon = callDaemon, startDaemon: start = startDaemon, cli = runCli }) {
  const body = { repo: root, query, limit: topK };
  try {
    return (await daemon('/search', body)).results;
  } catch {
    try {
      await start();
      return (await daemon('/search', body)).results;
    } catch {
      const collection = collectionName(root);
      return toCliResults(await cli(['query', query, '--json', '-n', String(topK), '-c', collection, '--chunk-strategy', 'auto']), collection);
    }
  }
}

async function main() {
  const { values } = parseArgs({ options: { query: { type: 'string' }, 'top-k': { type: 'string', default: '5' }, root: { type: 'string' }, stop: { type: 'boolean' } } });
  if (values.stop) {
    try { await callDaemon('/stop', {}); } catch { /* nothing running */ }
    return;
  }
  if (!values.query?.trim()) throw new Error('--query is required');
  const root = resolve(values.root || execFileSync('git', ['rev-parse', '--show-toplevel'], { encoding: 'utf8' }).trim());
  const topK = Math.min(Math.max(Number(values['top-k']) || 5, 1), 20);
  process.stdout.write(JSON.stringify(await runSearch({ root, query: values.query, topK }), null, 2) + '\n');
}

if (import.meta.url === pathToFileURL(process.argv[1] || '').href) {
  main().catch((error) => { console.error(`semantic-search: ${error.message}`); process.exit(1); });
}
