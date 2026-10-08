// shared/qmd/qmd-daemon.mjs — keeps QMD's models loaded for fast searches; exits when idle.
import { execFileSync } from 'node:child_process';
import { randomBytes, timingSafeEqual } from 'node:crypto';
import { existsSync, readFileSync, statSync } from 'node:fs';
import { createServer as createHttpServer } from 'node:http';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { setCollectionIgnore } from './qmd-config.mjs';
import { MASK, collectionName, idleMinutes, importQmd, qmdConfigPath, qmdDbPath, readJson, runQmdCli, stateDir, writePrivateJson, writeTextAtomic } from './qmd-lib.mjs';

const MAX_BODY = 64 * 1024;

// Dirty files keep the same porcelain line when edited again, so mtime and size of each listed path are part of the fingerprint.
export function gitFingerprint(repo) {
  try {
    const status = execFileSync('git', ['-C', repo, 'status', '--porcelain=v1', '-uall', '-z'], { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024, windowsHide: true });
    const stats = status.split('\0').filter((entry) => entry.length > 3).map((entry) => {
      try {
        const stat = statSync(join(repo, entry.slice(3)));
        return `${entry}|${stat.mtimeMs}:${stat.size}`;
      } catch {
        return `${entry}|deleted`;
      }
    });
    return `${stats.join('\n')}\n` + execFileSync('git', ['-C', repo, 'rev-parse', 'HEAD'], { encoding: 'utf8', windowsHide: true });
  } catch {
    return String(Date.now());
  }
}

// git ls-files -z --directory output: ignored directories end with '/' and become 'dir/**'; escape quotes glob syntax in names.
export function ignoreGlobs(output, escape) {
  return output.split('\0').filter(Boolean).map((path) => (path.endsWith('/') ? `${escape(path.slice(0, -1))}/**` : escape(path)));
}

export function gitIgnored(repo, escape) {
  try {
    return ignoreGlobs(execFileSync('git', ['-C', repo, 'ls-files', '-z', '--others', '--ignored', '--exclude-standard', '--directory'],
      { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024, windowsHide: true }), escape);
  } catch {
    return [];
  }
}

// QMD 2.8.3 createStore unloads models after 5 idle minutes (store.internal.llm); the daemon's own idle exit replaces that.
export function keepModelsLoaded(store) {
  const llm = store.internal?.llm;
  if (!llm) return;
  llm.inactivityTimeoutMs = 0;
  llm.disposeModelsOnInactivity = false;
}

const REPO_COLLECTION = /^repo-[0-9a-f]{12}$/;

function tokenMatches(given, expected) {
  const a = Buffer.from(String(given ?? ''));
  const b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}

export function createServer({ store, token, idleMs, now = Date.now, onIdle, extractSnippet, git = gitFingerprint,
  excludeCollection, recordCollection, ignored, persistIgnore }) {
  let lastRequest = now();
  let active = 0;
  const known = new Set();
  const fingerprints = new Map();
  const ignoreKeys = new Map();

  const inFlight = new Map();

  function refresh(repo) {
    const name = collectionName(repo);
    if (!inFlight.has(name)) inFlight.set(name, doRefresh(repo, name).finally(() => inFlight.delete(name)));
    return inFlight.get(name);
  }

  async function doRefresh(repo, name) {
    const fingerprint = git(repo);
    let ignore;
    if (!known.has(name)) {
      const existing = (await store.listCollections()).some((c) => c.name === name);
      if (!existing) {
        ignore = ignored(repo);
        await store.addCollection(name, { path: resolve(repo), pattern: MASK, ignore });
      }
      try {
        await excludeCollection(name);
        recordCollection(name);
        known.add(name);
      } catch (error) {
        console.error(`qmd-daemon: could not exclude ${name} from default search: ${error.message}`);
      }
    }
    if (fingerprints.get(name) === fingerprint) return { collection: name, updated: false };
    ignore ??= ignored(repo);
    const ignoreKey = JSON.stringify(ignore);
    if (ignoreKeys.get(name) !== ignoreKey) {
      try {
        await persistIgnore(name, ignore);
        ignoreKeys.set(name, ignoreKey);
      } catch (error) {
        console.error(`qmd-daemon: could not save the git ignore list of ${name}: ${error.message}`);
      }
    }
    await store.update({ collections: [name] });
    await store.embed({ collection: name, chunkStrategy: 'auto' });
    fingerprints.set(name, fingerprint);
    return { collection: name, updated: true };
  }

  async function search({ repo, query, limit }) {
    const { collection } = await refresh(repo);
    const defaults = (await store.getDefaultCollectionNames()).filter((n) => !REPO_COLLECTION.test(n));
    const results = await store.search({ query, collections: [collection, ...defaults], limit: Number.isInteger(limit) ? Math.min(20, Math.max(1, limit)) : 5, chunkStrategy: 'auto' });
    return results.map((r) => {
      const { line, snippet } = extractSnippet(r.body, query, 300, r.bestChunkPos, r.bestChunk.length);
      // displayPath is <collection>/<path>: repo hits become repo-relative, others stay addressable as qmd:// URIs.
      const path = r.displayPath.startsWith(`${collection}/`) ? r.displayPath.slice(collection.length + 1) : `qmd://${r.displayPath}`;
      return { path, line, score: Math.round(r.score * 100) / 100, snippet };
    });
  }

  const server = createHttpServer(async (request, response) => {
    const reply = (status, value) => {
      response.writeHead(status, { 'content-type': 'application/json' });
      response.end(JSON.stringify(value));
    };
    if (!tokenMatches(request.headers['x-qmd-token'], token)) return reply(403, { error: 'forbidden' });
    active++;
    lastRequest = now();
    try {
      if (request.method === 'GET' && request.url === '/health') return reply(200, { status: 'ok', service: 'ai-config-qmd', pid: process.pid });
      request.setEncoding('utf8');
      let raw = '';
      for await (const chunk of request) {
        raw += chunk;
        if (raw.length > MAX_BODY) return reply(413, { error: 'body too large' });
      }
      let body;
      try { body = raw ? JSON.parse(raw) : {}; } catch { return reply(400, { error: 'invalid JSON' }); }
      if (!body || typeof body !== 'object' || Array.isArray(body)) return reply(400, { error: 'body must be an object' });
      if (request.method === 'POST' && request.url === '/stop') {
        reply(200, { stopping: true });
        return onIdle();
      }
      if (typeof body.repo !== 'string' || !body.repo) return reply(400, { error: 'repo is required' });
      if (request.method === 'POST' && request.url === '/refresh') return reply(200, await refresh(body.repo));
      if (request.method === 'POST' && request.url === '/search') {
        if (typeof body.query !== 'string' || !body.query.trim()) return reply(400, { error: 'query is required' });
        return reply(200, { results: await search(body) });
      }
      return reply(404, { error: 'not found' });
    } catch (error) {
      return reply(500, { error: String(error?.message || error) });
    } finally {
      active--;
      lastRequest = now();
    }
  });

  const checkIdle = () => { if (active === 0 && now() - lastRequest >= idleMs) onIdle(); };
  return { server, refresh, search, checkIdle };
}

async function main() {
  const dir = stateDir();
  const daemonFile = join(dir, 'daemon.json');
  const current = readJson(daemonFile, null);
  if (current) {
    try {
      const health = await fetch(`http://127.0.0.1:${current.port}/health`, { headers: { 'x-qmd-token': current.token }, signal: AbortSignal.timeout(2000) });
      if (health.ok && (await health.json()).service === 'ai-config-qmd') return;
    } catch { /* stale file: start a new daemon */ }
  }
  const { createStore, extractSnippet } = await importQmd();
  const store = await createStore({ dbPath: qmdDbPath(), configPath: qmdConfigPath() });
  keepModelsLoaded(store);
  // QMD keeps index.yml authoritative: createStore and the CLI re-sync it into SQLite, and its addCollection
  // write-through drops `ignore`, so the list is written into index.yml and re-synced the way QMD does it.
  const fastGlob = (await importQmd(join('node_modules', 'fast-glob', 'out', 'index.js'))).default;
  const YAML = await importQmd(join('node_modules', 'yaml', 'dist', 'index.js'));
  const { loadConfig } = await importQmd(join('dist', 'collections.js'));
  const { syncConfigToDb } = await importQmd(join('dist', 'store.js'));
  const collectionsFile = join(dir, 'collections.json');
  const token = randomBytes(32).toString('hex');
  let stopping = false;
  const stop = async () => {
    if (stopping) return;
    stopping = true;
    const latest = readJson(daemonFile, null);
    if (latest?.pid === process.pid) writePrivateJson(daemonFile, { stopped: true });
    daemon.server.close();
    daemon.server.closeIdleConnections();
    await store.close();
    process.exit(0);
  };
  const daemon = createServer({
    store, token, idleMs: idleMinutes() * 60_000, onIdle: stop, extractSnippet,
    ignored: (repo) => gitIgnored(repo, fastGlob.escapePath),
    persistIgnore: async (name, ignore) => {
      const path = qmdConfigPath();
      const text = existsSync(path) ? readFileSync(path, 'utf8') : '';
      const next = setCollectionIgnore(text, YAML, name, ignore);
      if (next === null) return; // never re-sync without the collection: the sync would delete it from SQLite
      if (next !== text) writeTextAtomic(path, next);
      syncConfigToDb(store.internal.db, loadConfig());
    },
    excludeCollection: async (name) => { runQmdCli(['collection', 'exclude', name], { windowsHide: true, stdio: 'ignore' }); },
    recordCollection: (name) => {
      const names = new Set(readJson(collectionsFile, []));
      names.add(name);
      writePrivateJson(collectionsFile, [...names].sort());
    },
  });
  daemon.server.listen(0, '127.0.0.1', () => {
    writePrivateJson(daemonFile, { port: daemon.server.address().port, token, pid: process.pid });
  });
  setInterval(daemon.checkIdle, 60_000).unref();
  process.on('SIGTERM', stop);
  process.on('SIGINT', stop);
}

if (import.meta.url === pathToFileURL(process.argv[1] || '').href) {
  main().catch((error) => { console.error(`qmd-daemon: ${error.message}`); process.exit(1); });
}
