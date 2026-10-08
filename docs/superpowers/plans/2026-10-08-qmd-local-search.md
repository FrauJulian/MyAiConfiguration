# QMD Local Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Python Qwen retrieval stack with QMD (Qwen3 embedding, Qwen3 reranker, QMD query expansion) behind the existing Yes/No/Auto local-models question, with a strict `semantic-search` skill for Claude and Codex.

**Architecture:** Node scripts in `shared/qmd/` drive QMD through its SDK: a token-protected loopback daemon keeps the three models loaded and exits after 30 idle minutes; a search wrapper talks to it and falls back to `qmd query --json`; a SessionStart hook warms the daemon and the repository collection. A Python installer library (`scripts/lib/qmd.py`, with `.sh`/`.ps1` wrappers, the same pattern as the removed `semantic-retrieval.py`) installs, benchmarks, migrates, and removes setup-owned QMD state.

**Tech Stack:** Node.js 22+ (ESM, `node:test`), `@tobilu/qmd@2.8.3` SDK and its bundled `yaml` and `node-llama-cpp` packages, Python 3.12 stdlib (`unittest`), Bash and PowerShell 5.1/7.

**Spec:** `docs/superpowers/specs/2026-10-08-qmd-local-search-design.md`

## Global Constraints

- Models (exact URIs): embed `hf:Qwen/Qwen3-Embedding-0.6B-GGUF/Qwen3-Embedding-0.6B-Q8_0.gguf`; rerank `hf:ggml-org/Qwen3-Reranker-0.6B-Q8_0-GGUF/qwen3-reranker-0.6b-q8_0.gguf`; generate `hf:tobil/qmd-query-expansion-1.7B-gguf/qmd-query-expansion-1.7B-q4_k_m.gguf`.
- QMD package: `@tobilu/qmd@2.8.3`; Node.js 22 or newer; `npm` required.
- No Python code loads or runs a model. Python is used only by the installer library, as elsewhere in `scripts/lib/`.
- Auto thresholds: median search latency at most 5 s (`QMD_BENCHMARK_MAX_QUERY_SECONDS`); embedding at least 20 chunks/s (`QMD_BENCHMARK_MIN_CHUNKS_PER_SECOND`); GPU first, then CPU; 10-minute timeout per device.
- Idle stop: `QMD_IDLE_MINUTES`, default 30.
- Platforms: Linux and Windows are both first-class (the CI runner is Ubuntu; Windows is verified locally in Task 11). Spawned processes use `windowsHide`, `npm`/`qmd` run with `shell: true` only on Windows, hooks have `.sh` and `.ps1` entry points.
- Multiple GPUs and CPUs: the setup never narrows the device set. `gpu` mode uses llama.cpp's automatic backend, which spreads layers over every GPU of that backend; `cpu` mode uses every logical core (node-llama-cpp default). The setup never sets `CUDA_VISIBLE_DEVICES`, `GGML_VK_VISIBLE_DEVICES`, or a thread limit. Mixed-vendor systems use the one backend llama.cpp picks (CUDA before Vulkan); the benchmark reports the GPU names it used.
- Repository collection: `repo-` + first 12 hex chars of SHA-256 of the resolved absolute repository path; mask `**/*.{md,py,cs,ts,tsx,js,jsx,mjs,go,rs,java,ps1,sh,json,yml,yaml,xml,sql}`; chunk strategy `auto`; `includeByDefault: false`.
- State: `~/.my-ai-configuration/qmd.json` (installer state) and `~/.my-ai-configuration/qmd/` (installed scripts, `daemon.json`, `collections.json`, `warm.log`). Selection key stays `semantic_retrieval`; parameters stay `-SemanticRetrieval` / `--semantic-retrieval`.
- The setup removes only what it created: QMD package, model files, repo collections, the `models:` block it wrote. Foreign installs and collections survive.
- Every hook has `.sh` and `.ps1` entry points; PowerShell code stays 5.1-compatible. The `.mjs` scripts are invoked as `node <script>` from both shells.
- All repository content and script output in English. Commit after each task with Conventional Commits and the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; never push.

## Review Focus

- A repository path containing spaces or non-ASCII characters: the collection name must be stable and the search must still work. Test in Task 1 (`collectionName` with spaces/umlauts) and Task 3 (wrapper on such a path).
- A stale `daemon.json` after a crash or reboot (dead PID, reused port, wrong token): the wrapper must recover by starting a new daemon or falling back to the CLI, never hang. Test in Task 3.
- Two sessions starting at once in the same repository: only one indexing run and one daemon. Test in Task 4 (lock) and Task 2 (second daemon start is a no-op).
- An existing user `index.yml` with collections and comments: the setup changes only `models:` and leaves the rest byte-for-byte equivalent in meaning. Test in Task 1 (`setModels`/`unsetModels`).
- Answer No after a previous Yes on a machine where QMD was installed by the user before the setup: QMD and the user's collections must survive. Test in Task 6.
- A machine with several GPUs or several CPU sockets: no device may be excluded by the setup's environment. Test in Task 1 (`deviceEnv` never sets visibility or thread variables) and Task 5 (`describeDevices` lists every GPU name).

---

### Task 1: Shared Node library (`qmd-lib.mjs`) and `index.yml` model block

**Files:**
- Create: `shared/qmd/qmd-lib.mjs`
- Create: `shared/qmd/qmd-config.mjs`
- Test: `scripts/tests/test-qmd-lib.mjs`

**Interfaces:**
- Produces (`qmd-lib.mjs`):
  - `MODELS: {embed, rerank, generate}` (strings above)
  - `MASK: string`
  - `collectionName(repoPath: string): string`
  - `stateDir(home?: string): string` → `<home>/.my-ai-configuration/qmd`
  - `setupStatePath(home?: string): string` → `<home>/.my-ai-configuration/qmd.json`
  - `qmdConfigPath(env?: object, home?: string): string`
  - `qmdDbPath(env?: object, home?: string): string`
  - `deviceEnv(device: 'gpu'|'cpu', env?: object): object`
  - `readJson(path: string, fallback: any): any`
  - `writePrivateJson(path: string, value: any): void`
  - `qmdPackageDir(): string` (honors `QMD_PACKAGE_DIR`)
  - `importQmd(subpath?: string): Promise<module>` (default `dist/index.js`)
  - `idleMinutes(env?: object): number`
- Produces (`qmd-config.mjs`): CLI `node qmd-config.mjs set-models|unset-models` and exported `setModels(text: string, YAML): string`, `unsetModels(text: string, YAML): string`.

- [ ] **Step 1: Write the failing tests**

```js
// scripts/tests/test-qmd-lib.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import * as YAML from './fixtures/yaml-shim.mjs';
import { collectionName, deviceEnv, idleMinutes, qmdConfigPath, writePrivateJson, readJson, MODELS } from '../../shared/qmd/qmd-lib.mjs';
import { setModels, unsetModels } from '../../shared/qmd/qmd-config.mjs';

test('collection name is stable, prefixed, and path-safe', () => {
  const a = collectionName('/tmp/My Repo/ü');
  assert.match(a, /^repo-[0-9a-f]{12}$/);
  assert.equal(a, collectionName('/tmp/My Repo/ü'));
  assert.notEqual(a, collectionName('/tmp/My Repo/u'));
});

test('device env forces CPU or enables GPU auto', () => {
  assert.equal(deviceEnv('cpu', { QMD_LLAMA_GPU: 'cuda' }).QMD_FORCE_CPU, '1');
  assert.equal(deviceEnv('cpu', { QMD_LLAMA_GPU: 'cuda' }).QMD_LLAMA_GPU, undefined);
  assert.equal(deviceEnv('gpu', { QMD_FORCE_CPU: '1' }).QMD_LLAMA_GPU, 'auto');
  assert.equal(deviceEnv('gpu', { QMD_FORCE_CPU: '1' }).QMD_FORCE_CPU, undefined);
});

test('device env never narrows GPUs or threads', () => {
  for (const device of ['gpu', 'cpu']) {
    const env = deviceEnv(device, {});
    for (const key of ['CUDA_VISIBLE_DEVICES', 'GGML_VK_VISIBLE_DEVICES', 'HIP_VISIBLE_DEVICES', 'OMP_NUM_THREADS']) assert.equal(env[key], undefined);
  }
});

test('idle minutes default to 30 and reject nonsense', () => {
  assert.equal(idleMinutes({}), 30);
  assert.equal(idleMinutes({ QMD_IDLE_MINUTES: '5' }), 5);
  assert.equal(idleMinutes({ QMD_IDLE_MINUTES: '-1' }), 30);
});

test('config path honors QMD_CONFIG_DIR then XDG_CONFIG_HOME', () => {
  assert.equal(qmdConfigPath({ QMD_CONFIG_DIR: '/c' }, '/h'), join('/c', 'index.yml'));
  assert.equal(qmdConfigPath({ XDG_CONFIG_HOME: '/x' }, '/h'), join('/x', 'qmd', 'index.yml'));
  assert.equal(qmdConfigPath({}, '/h'), join('/h', '.config', 'qmd', 'index.yml'));
});

test('private json round-trips', () => {
  const file = join(mkdtempSync(join(tmpdir(), 'qmd-lib-')), 'a', 'b.json');
  writePrivateJson(file, { x: 1 });
  assert.deepEqual(readJson(file, null), { x: 1 });
  assert.equal(readJson(file + '.missing', 'fallback'), 'fallback');
});

test('setModels keeps collections and comments, unsetModels removes only models', () => {
  const original = '# mine\ncollections:\n  notes:\n    path: /n # keep\n';
  const withModels = setModels(original, YAML);
  assert.match(withModels, /# mine/);
  assert.match(withModels, /path: \/n # keep/);
  assert.match(withModels, new RegExp(MODELS.embed.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  const restored = unsetModels(withModels, YAML);
  assert.doesNotMatch(restored, /models:/);
  assert.match(restored, /path: \/n # keep/);
});

test('setModels on an empty file creates only the models block', () => {
  const text = setModels('', YAML);
  assert.match(text, /^models:/m);
});
```

```js
// scripts/tests/fixtures/yaml-shim.mjs — loads QMD's bundled yaml package for tests.
import { qmdPackageDir } from '../../../shared/qmd/qmd-lib.mjs';
import { pathToFileURL } from 'node:url';
import { join } from 'node:path';
const YAML = await import(pathToFileURL(join(qmdPackageDir(), 'node_modules', 'yaml', 'dist', 'index.js')).href);
export const parseDocument = YAML.parseDocument;
export default YAML;
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `node --test scripts/tests/test-qmd-lib.mjs`
Expected: FAIL with `Cannot find module '.../shared/qmd/qmd-lib.mjs'`

- [ ] **Step 3: Implement `qmd-lib.mjs`**

```js
// shared/qmd/qmd-lib.mjs
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export const MODELS = {
  embed: 'hf:Qwen/Qwen3-Embedding-0.6B-GGUF/Qwen3-Embedding-0.6B-Q8_0.gguf',
  rerank: 'hf:ggml-org/Qwen3-Reranker-0.6B-Q8_0-GGUF/qwen3-reranker-0.6b-q8_0.gguf',
  generate: 'hf:tobil/qmd-query-expansion-1.7B-gguf/qmd-query-expansion-1.7B-q4_k_m.gguf',
};
export const MASK = '**/*.{md,py,cs,ts,tsx,js,jsx,mjs,go,rs,java,ps1,sh,json,yml,yaml,xml,sql}';

export function collectionName(repoPath) {
  return 'repo-' + createHash('sha256').update(resolve(repoPath), 'utf8').digest('hex').slice(0, 12);
}

export const stateDir = (home = homedir()) => join(home, '.my-ai-configuration', 'qmd');
export const setupStatePath = (home = homedir()) => join(home, '.my-ai-configuration', 'qmd.json');

export function qmdConfigPath(env = process.env, home = homedir()) {
  const dir = env.QMD_CONFIG_DIR || (env.XDG_CONFIG_HOME ? join(env.XDG_CONFIG_HOME, 'qmd') : join(home, '.config', 'qmd'));
  return join(dir, 'index.yml');
}

export function qmdDbPath(env = process.env, home = homedir()) {
  return join(env.XDG_CACHE_HOME || join(home, '.cache'), 'qmd', 'index.sqlite');
}

export function deviceEnv(device, env = process.env) {
  const result = { ...env };
  if (device === 'cpu') {
    result.QMD_FORCE_CPU = '1';
    delete result.QMD_LLAMA_GPU;
  } else {
    result.QMD_LLAMA_GPU = 'auto';
    delete result.QMD_FORCE_CPU;
  }
  return result;
}

export function idleMinutes(env = process.env) {
  const value = Number(env.QMD_IDLE_MINUTES);
  return Number.isFinite(value) && value > 0 ? value : 30;
}

export function readJson(path, fallback) {
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch {
    return fallback;
  }
}

// The state directory lives in the user profile; mode 0600 restricts the token on POSIX.
export function writePrivateJson(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  const temporary = `${path}.${process.pid}.tmp`;
  writeFileSync(temporary, JSON.stringify(value, null, 2) + '\n', { mode: 0o600 });
  renameSync(temporary, path);
}

export function qmdPackageDir() {
  if (process.env.QMD_PACKAGE_DIR) return process.env.QMD_PACKAGE_DIR;
  const root = execFileSync('npm', ['root', '--global'], { encoding: 'utf8', shell: process.platform === 'win32' }).trim();
  return join(root, '@tobilu', 'qmd');
}

export function importQmd(subpath = join('dist', 'index.js')) {
  return import(pathToFileURL(join(qmdPackageDir(), subpath)).href);
}
```

- [ ] **Step 4: Implement `qmd-config.mjs`**

```js
// shared/qmd/qmd-config.mjs — edits only the models: block of QMD's index.yml.
import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { MODELS, qmdConfigPath, qmdPackageDir } from './qmd-lib.mjs';

export function setModels(text, YAML) {
  const document = YAML.parseDocument(text || '');
  if (document.errors.length) throw new Error(`index.yml cannot be parsed: ${document.errors[0].message}`);
  if (document.contents === null) document.contents = document.createNode({});
  document.set('models', document.createNode({ ...MODELS }));
  return document.toString();
}

export function unsetModels(text, YAML) {
  const document = YAML.parseDocument(text || '');
  if (document.errors.length) throw new Error(`index.yml cannot be parsed: ${document.errors[0].message}`);
  if (document.contents !== null) document.delete('models');
  return document.contents === null || document.contents.items?.length === 0 ? '' : document.toString();
}

async function main(action) {
  if (!['set-models', 'unset-models'].includes(action)) throw new Error('usage: qmd-config.mjs set-models|unset-models');
  const YAML = await import(pathToFileURL(join(qmdPackageDir(), 'node_modules', 'yaml', 'dist', 'index.js')).href);
  const path = qmdConfigPath();
  const current = existsSync(path) ? readFileSync(path, 'utf8') : '';
  const next = action === 'set-models' ? setModels(current, YAML) : unsetModels(current, YAML);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, next);
}

if (import.meta.url === pathToFileURL(process.argv[1] || '').href) {
  main(process.argv[2]).catch((error) => { console.error(`qmd-config: ${error.message}`); process.exit(1); });
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `node --test scripts/tests/test-qmd-lib.mjs`
Expected: PASS, 8 tests. (Needs `@tobilu/qmd` installed globally for the YAML shim; CI installs it in Task 10.)

- [ ] **Step 6: Commit**

```bash
git add shared/qmd/qmd-lib.mjs shared/qmd/qmd-config.mjs scripts/tests/test-qmd-lib.mjs scripts/tests/fixtures/yaml-shim.mjs
git commit -m "feat(qmd): add shared Node helpers and index.yml model block editing"
```

---

### Task 2: Search daemon (`qmd-daemon.mjs`)

**Files:**
- Create: `shared/qmd/qmd-daemon.mjs`
- Test: `scripts/tests/test-qmd-daemon.mjs`

**Interfaces:**
- Consumes: `collectionName`, `MASK`, `stateDir`, `qmdConfigPath`, `qmdDbPath`, `writePrivateJson`, `readJson`, `idleMinutes`, `importQmd` from Task 1.
- Produces:
  - `createServer({ store, extractSnippet, now, idleMs, onIdle, token, git }): { server, refresh(repo), search(body) }` (exported for tests)
  - HTTP API on `127.0.0.1:<port>`, header `x-qmd-token: <token>` required:
    - `GET /health` → `{ status: 'ok', service: 'ai-config-qmd', pid }`
    - `POST /refresh` body `{ repo }` → `{ collection, updated: boolean }`
    - `POST /search` body `{ repo, query, limit }` → `{ results: [{ path, line, score, snippet }] }`
    - `POST /stop` → `{ stopping: true }`
  - `daemon.json` in `stateDir()`: `{ port, token, pid }`
  - `collections.json` in `stateDir()`: array of repo collection names the setup created.

- [ ] **Step 1: Write the failing tests**

```js
// scripts/tests/test-qmd-daemon.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from '../../shared/qmd/qmd-daemon.mjs';

function fakeStore() {
  const calls = [];
  return {
    calls,
    listCollections: async () => [{ name: 'notes', includeByDefault: true }],
    getDefaultCollectionNames: async () => ['notes', 'repo-aaaaaaaaaaaa'],
    addCollection: async (name, opts) => calls.push(['add', name, opts]),
    update: async (opts) => { calls.push(['update', opts]); return { indexed: 1 }; },
    embed: async (opts) => { calls.push(['embed', opts]); return { chunksEmbedded: 1 }; },
    search: async (opts) => { calls.push(['search', opts]); return [{ displayPath: 'src/a.ts', body: 'x\nretry here', bestChunkPos: 2, bestChunk: 'retry here', score: 0.91, file: 'qmd://repo/src/a.ts' }]; },
  };
}

async function start(overrides = {}) {
  const store = fakeStore();
  let clock = 0;
  const idle = [];
  const daemon = createServer({
    store, token: 't0k', idleMs: 1000, now: () => clock, onIdle: () => idle.push(clock),
    extractSnippet: (body) => ({ line: 2, snippet: 'retry here' }),
    git: () => 'fingerprint-1', excludeCollection: async () => {}, recordCollection: () => {}, ...overrides,
  });
  await new Promise((done) => daemon.server.listen(0, '127.0.0.1', done));
  const port = daemon.server.address().port;
  const call = (path, body, token = 't0k') => fetch(`http://127.0.0.1:${port}${path}`, {
    method: body === undefined ? 'GET' : 'POST', headers: { 'x-qmd-token': token, 'content-type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body) });
  return { daemon, store, call, setClock: (v) => { clock = v; }, idle, close: () => daemon.server.close() };
}

test('rejects requests without the token', async () => {
  const s = await start();
  assert.equal((await s.call('/health', undefined, 'wrong')).status, 403);
  s.close();
});

test('health identifies the service', async () => {
  const s = await start();
  assert.equal((await (await s.call('/health')).json()).service, 'ai-config-qmd');
  s.close();
});

test('search adds the repo collection once, refreshes on change, and filters other repos', async () => {
  const s = await start();
  const body = await (await s.call('/search', { repo: '/r', query: 'where are retries', limit: 3 })).json();
  assert.deepEqual(body.results, [{ path: 'src/a.ts', line: 2, score: 0.91, snippet: 'retry here' }]);
  const search = s.store.calls.find((c) => c[0] === 'search')[1];
  assert.equal(search.query, 'where are retries');
  assert.ok(search.collections.includes('notes'));
  assert.ok(!search.collections.includes('repo-aaaaaaaaaaaa'));
  assert.equal(search.collections.filter((n) => n.startsWith('repo-')).length, 1);
  assert.equal(s.store.calls.filter((c) => c[0] === 'add').length, 1);
  await s.call('/search', { repo: '/r', query: 'again', limit: 3 });
  assert.equal(s.store.calls.filter((c) => c[0] === 'update').length, 1, 'unchanged fingerprint skips update');
  s.close();
});

test('rejects a missing query', async () => {
  const s = await start();
  assert.equal((await s.call('/search', { repo: '/r' })).status, 400);
  s.close();
});

test('idle check calls onIdle only after the idle window', async () => {
  const s = await start();
  s.setClock(500); s.daemon.checkIdle(); assert.deepEqual(s.idle, []);
  s.setClock(1500); s.daemon.checkIdle(); assert.deepEqual(s.idle, [1500]);
  s.close();
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `node --test scripts/tests/test-qmd-daemon.mjs`
Expected: FAIL with `Cannot find module '.../shared/qmd/qmd-daemon.mjs'`

- [ ] **Step 3: Implement `qmd-daemon.mjs`**

```js
// shared/qmd/qmd-daemon.mjs — keeps QMD's models loaded for fast searches; exits when idle.
import { execFileSync, spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { createServer as createHttpServer } from 'node:http';
import { join, relative } from 'node:path';
import { pathToFileURL } from 'node:url';
import { MASK, collectionName, idleMinutes, importQmd, qmdConfigPath, qmdDbPath, readJson, stateDir, writePrivateJson } from './qmd-lib.mjs';

const MAX_BODY = 64 * 1024;

function gitFingerprint(repo) {
  try {
    return execFileSync('git', ['-C', repo, 'status', '--porcelain=v1', '-uall'], { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 })
      + execFileSync('git', ['-C', repo, 'rev-parse', 'HEAD'], { encoding: 'utf8' });
  } catch {
    return String(Date.now());
  }
}

export function createServer({ store, token, idleMs, now = Date.now, onIdle, extractSnippet, git = gitFingerprint,
  excludeCollection, recordCollection }) {
  let lastRequest = now();
  const known = new Set();
  const fingerprints = new Map();

  async function refresh(repo) {
    const name = collectionName(repo);
    if (!known.has(name)) {
      const existing = (await store.listCollections()).some((c) => c.name === name);
      if (!existing) {
        await store.addCollection(name, { path: repo, pattern: MASK });
        await excludeCollection(name);
        recordCollection(name);
      }
      known.add(name);
    }
    const fingerprint = git(repo);
    if (fingerprints.get(name) === fingerprint) return { collection: name, updated: false };
    await store.update({ collections: [name] });
    await store.embed({ collection: name, chunkStrategy: 'auto' });
    fingerprints.set(name, fingerprint);
    return { collection: name, updated: true };
  }

  async function search({ repo, query, limit }) {
    const { collection } = await refresh(repo);
    const defaults = (await store.getDefaultCollectionNames()).filter((n) => !n.startsWith('repo-'));
    const results = await store.search({ query, collections: [collection, ...defaults], limit: limit || 5, chunkStrategy: 'auto' });
    return results.map((r) => {
      const { line, snippet } = extractSnippet(r.body, query, 300, r.bestChunkPos, r.bestChunk.length);
      const path = r.file?.startsWith(`qmd://${collection}/`) || !r.file?.startsWith('qmd://') ? r.displayPath : r.file;
      return { path, line, score: Math.round(r.score * 100) / 100, snippet };
    });
  }

  const server = createHttpServer(async (request, response) => {
    const reply = (status, value) => {
      response.writeHead(status, { 'content-type': 'application/json' });
      response.end(JSON.stringify(value));
    };
    if (request.headers['x-qmd-token'] !== token) return reply(403, { error: 'forbidden' });
    lastRequest = now();
    try {
      if (request.method === 'GET' && request.url === '/health') return reply(200, { status: 'ok', service: 'ai-config-qmd', pid: process.pid });
      let raw = '';
      for await (const chunk of request) {
        raw += chunk;
        if (raw.length > MAX_BODY) return reply(413, { error: 'body too large' });
      }
      const body = raw ? JSON.parse(raw) : {};
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
      lastRequest = now();
    }
  });

  const checkIdle = () => { if (now() - lastRequest >= idleMs) onIdle(); };
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
  const collectionsFile = join(dir, 'collections.json');
  const token = randomBytes(32).toString('hex');
  let stopping = false;
  const stop = async () => {
    if (stopping) return;
    stopping = true;
    const latest = readJson(daemonFile, null);
    if (latest?.pid === process.pid) writePrivateJson(daemonFile, { stopped: true });
    await store.close();
    process.exit(0);
  };
  const daemon = createServer({
    store, token, idleMs: idleMinutes() * 60_000, onIdle: stop, extractSnippet,
    excludeCollection: async (name) => { spawnSync('qmd', ['collection', 'exclude', name], { shell: process.platform === 'win32', stdio: 'ignore' }); },
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `node --test scripts/tests/test-qmd-daemon.mjs`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add shared/qmd/qmd-daemon.mjs scripts/tests/test-qmd-daemon.mjs
git commit -m "feat(qmd): add token-protected search daemon with idle exit"
```

---

### Task 3: Search wrapper (`qmd-search.mjs`)

**Files:**
- Create: `shared/qmd/qmd-search.mjs`
- Test: `scripts/tests/test-qmd-search.mjs`

**Interfaces:**
- Consumes: `stateDir`, `readJson`, `writePrivateJson`, `setupStatePath`, `deviceEnv`, `collectionName` (Task 1); daemon HTTP API (Task 2).
- Produces:
  - CLI: `node qmd-search.mjs --query "<question>" [--top-k 5] [--root <repo>]` → stdout JSON array `[{path, line, score, snippet}]`; exit 1 with a one-line stderr message on failure.
  - CLI: `node qmd-search.mjs --stop` → asks a running daemon to stop; exit 0 even when none runs.
  - Exported `runSearch({ root, query, topK, daemon, startDaemon, cli }): Promise<results>` for tests, where `daemon(path, body)` returns parsed JSON or throws, `startDaemon()` returns a promise, and `cli(args)` returns parsed JSON.

- [ ] **Step 1: Write the failing tests**

```js
// scripts/tests/test-qmd-search.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { runSearch, toCliResults } from '../../shared/qmd/qmd-search.mjs';

const hit = [{ path: 'src/a.ts', line: 3, score: 0.9, snippet: 's' }];

test('uses the daemon when it answers', async () => {
  const results = await runSearch({ root: '/My Repo/ü', query: 'q', topK: 5,
    daemon: async (path, body) => { assert.equal(path, '/search'); assert.equal(body.repo, '/My Repo/ü'); return { results: hit }; },
    startDaemon: async () => assert.fail('must not start'), cli: async () => assert.fail('must not fall back') });
  assert.deepEqual(results, hit);
});

test('starts the daemon once when the first call fails, then retries', async () => {
  let calls = 0; let started = 0;
  const results = await runSearch({ root: '/r', query: 'q', topK: 5,
    daemon: async () => { calls += 1; if (calls === 1) throw new Error('ECONNREFUSED'); return { results: hit }; },
    startDaemon: async () => { started += 1; }, cli: async () => assert.fail('must not fall back') });
  assert.deepEqual(results, hit);
  assert.equal(started, 1);
});

test('falls back to the CLI when the daemon cannot start', async () => {
  const results = await runSearch({ root: '/r', query: 'q', topK: 2,
    daemon: async () => { throw new Error('stale'); }, startDaemon: async () => { throw new Error('spawn failed'); },
    cli: async (args) => { assert.ok(args.includes('--json')); return [{ file: 'qmd://repo-x/src/b.ts', line: 7, score: 0.5, snippet: 'b' }]; } });
  assert.deepEqual(results, [{ path: 'src/b.ts', line: 7, score: 0.5, snippet: 'b' }]);
});

test('CLI results keep foreign collections as qmd URIs', () => {
  assert.deepEqual(toCliResults([{ file: 'qmd://notes/x.md', line: 1, score: 0.4, snippet: 'n' }], 'repo-x'),
    [{ path: 'qmd://notes/x.md', line: 1, score: 0.4, snippet: 'n' }]);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `node --test scripts/tests/test-qmd-search.mjs`
Expected: FAIL with `Cannot find module '.../shared/qmd/qmd-search.mjs'`

- [ ] **Step 3: Implement `qmd-search.mjs`**

```js
// shared/qmd/qmd-search.mjs — search the current repository through the QMD daemon, with a CLI fallback.
import { execFileSync, spawn } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';
import { collectionName, deviceEnv, readJson, setupStatePath, stateDir } from './qmd-lib.mjs';

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

async function startDaemon() {
  const device = readJson(setupStatePath(), {}).device || 'cpu';
  const child = spawn(process.execPath, [join(here, 'qmd-daemon.mjs')], { detached: true, stdio: 'ignore', windowsHide: true, env: deviceEnv(device) });
  child.unref();
  const deadline = Date.now() + 120_000;
  while (Date.now() < deadline) {
    await new Promise((done) => setTimeout(done, 500));
    const info = readJson(daemonFile(), null);
    if (info?.port && info.pid === child.pid) return;
  }
  throw new Error('daemon did not start within 120 s');
}

function runCli(args) {
  const device = readJson(setupStatePath(), {}).device || 'cpu';
  const output = execFileSync('qmd', args, { encoding: 'utf8', env: deviceEnv(device), shell: process.platform === 'win32', maxBuffer: 16 * 1024 * 1024 });
  return JSON.parse(output);
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
      return toCliResults(cli(['query', query, '--json', '-n', String(topK), '-c', collection, '--chunk-strategy', 'auto']), collection);
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
```

Note: the CLI fallback searches only the repository collection; a fresh repository without an index returns an empty list there, which the skill treats as "no hit".

- [ ] **Step 4: Run tests to verify they pass**

Run: `node --test scripts/tests/test-qmd-search.mjs`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add shared/qmd/qmd-search.mjs scripts/tests/test-qmd-search.mjs
git commit -m "feat(qmd): add search wrapper with daemon start and CLI fallback"
```

---

### Task 4: Warm-up script and SessionStart hook

**Files:**
- Create: `shared/qmd/qmd-warm.mjs`
- Create: `shared/hooks/scripts/qmd-warm.sh`, `shared/hooks/scripts/Start-QmdWarm.ps1`
- Modify: `adapters/claude/config/settings.json` (SessionStart), `adapters/codex/config/config.toml` (`[[hooks.SessionStart]]`, `writable_roots`)
- Modify: `scripts/lib/install-options.py` (`filter_options` gains `semantic_retrieval_enabled`), `scripts/lib/manifest.sh:131,208-215`, `scripts/lib/manifest.ps1:145,173,227` (pass the flag to the filter and strip the instruction line)
- Test: `scripts/tests/test-qmd-warm.mjs`, `scripts/tests/test-install-options.py`

**Interfaces:**
- Consumes: daemon API (Task 2), `startDaemon` behavior (Task 3).
- Produces:
  - `node qmd-warm.mjs --root <repo>`: exits 0 always; logs to `stateDir()/warm.log`.
  - Exported `withLock(lockPath, fn, now)`: runs `fn` only if no fresh lock (younger than 30 minutes) exists.
  - `filter_options(path, flashbang_enabled=True, statusline_enabled=True, semantic_retrieval_enabled=True)` removes hooks whose command names `qmd-warm.sh` or `Start-QmdWarm.ps1` when disabled.
  - `filter_instructions(text: str, semantic_retrieval_enabled: bool) -> str` removes lines that mention `` `semantic-search` `` when disabled.

- [ ] **Step 1: Write the failing tests**

```js
// scripts/tests/test-qmd-warm.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { withLock } from '../../shared/qmd/qmd-warm.mjs';

test('a fresh lock skips the second warm-up and is released afterwards', async () => {
  const lock = join(mkdtempSync(join(tmpdir(), 'qmd-warm-')), 'repo.lock');
  let runs = 0;
  await withLock(lock, async () => {
    runs += 1;
    await withLock(lock, async () => { runs += 1; });
  });
  assert.equal(runs, 1);
  assert.equal(existsSync(lock), false);
});

test('a stale lock older than 30 minutes is replaced', async () => {
  const lock = join(mkdtempSync(join(tmpdir(), 'qmd-warm-')), 'repo.lock');
  writeFileSync(lock, String(Date.now() - 31 * 60_000));
  let runs = 0;
  await withLock(lock, async () => { runs += 1; });
  assert.equal(runs, 1);
});
```

```python
# scripts/tests/test-install-options.py — add to the existing TestCase class
    def test_semantic_retrieval_disabled_removes_qmd_session_hook(self):
        settings = Path(self.directory) / 'settings.json'
        settings.write_text(json.dumps({'hooks': {'SessionStart': [
            {'hooks': [{'type': 'command', 'command': 'bash "/c/hooks/scripts/show-session-state-pointer.sh"'}]},
            {'hooks': [{'type': 'command', 'command': 'bash "/c/hooks/scripts/qmd-warm.sh"'}]}]}}), encoding='utf-8')
        result = json.loads(module.filter_options(settings, semantic_retrieval_enabled=False))
        commands = [hook['command'] for group in result['hooks']['SessionStart'] for hook in group['hooks']]
        self.assertEqual(commands, ['bash "/c/hooks/scripts/show-session-state-pointer.sh"'])

    def test_semantic_retrieval_disabled_removes_codex_session_hook(self):
        config = Path(self.directory) / 'config.toml'
        config.write_text('[features]\nhooks = true\n\n[[hooks.SessionStart]]\n[[hooks.SessionStart.hooks]]\ntype = "command"\n'
                          'command = \'bash "/c/hooks/scripts/qmd-warm.sh"\'\ncommand_windows = \'pwsh "/c/hooks/scripts/Start-QmdWarm.ps1"\'\ntimeout = 4\n',
                          encoding='utf-8')
        result = module.filter_options(config, semantic_retrieval_enabled=False)
        self.assertNotIn('qmd-warm', result)
        self.assertNotIn('hooks.SessionStart', result)

    def test_instruction_line_only_with_semantic_search(self):
        text = 'Line one.\nWhen `semantic-search` is installed, run it first.\nLine three.\n'
        self.assertEqual(module.filter_instructions(text, False), 'Line one.\nLine three.\n')
        self.assertEqual(module.filter_instructions(text, True), text)
```

(Use the module loader and `self.directory` temp-dir fixture the file already defines; if it names them differently, adapt the two identifiers only.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `node --test scripts/tests/test-qmd-warm.mjs` → FAIL (module missing).
Run: `python scripts/tests/test-install-options.py` → FAIL (`unexpected keyword argument 'semantic_retrieval_enabled'`).

- [ ] **Step 3: Implement `qmd-warm.mjs`**

```js
// shared/qmd/qmd-warm.mjs — background warm-up started by the SessionStart hook; never fails the session.
import { execFileSync } from 'node:child_process';
import { appendFileSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';
import { collectionName, stateDir } from './qmd-lib.mjs';
import { runSearch } from './qmd-search.mjs';

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

async function main() {
  const { values } = parseArgs({ options: { root: { type: 'string' } } });
  const root = resolve(values.root || execFileSync('git', ['rev-parse', '--show-toplevel'], { encoding: 'utf8' }).trim());
  const dir = stateDir();
  mkdirSync(dir, { recursive: true });
  await withLock(join(dir, `${collectionName(root)}.lock`), async () => {
    // A refresh through the daemon starts it if needed and indexes the repository incrementally.
    await runSearchRefresh(root);
  });
}

async function runSearchRefresh(root) {
  const { readJson } = await import('./qmd-lib.mjs');
  const call = async () => {
    const info = readJson(join(stateDir(), 'daemon.json'), null);
    if (!info?.port) throw new Error('daemon not running');
    const response = await fetch(`http://127.0.0.1:${info.port}/refresh`, { method: 'POST',
      headers: { 'x-qmd-token': info.token, 'content-type': 'application/json' }, body: JSON.stringify({ repo: root }),
      signal: AbortSignal.timeout(35 * 60_000) });
    if (!response.ok) throw new Error(`refresh answered ${response.status}`);
  };
  try {
    await call();
  } catch {
    await runSearch.startDaemon?.();
    const { startDaemonForWarm } = await import('./qmd-search.mjs');
    await startDaemonForWarm();
    await call();
  }
}

if (import.meta.url === pathToFileURL(process.argv[1] || '').href) {
  main().catch((error) => {
    try { appendFileSync(join(stateDir(), 'warm.log'), `${new Date().toISOString()} ${error.message}\n`); } catch { /* ignore */ }
  }).finally(() => process.exit(0));
}
```

Then export the daemon starter from Task 3's module for reuse (one source of truth): in `shared/qmd/qmd-search.mjs` add `export { startDaemon as startDaemonForWarm };` below the `startDaemon` function, and in `qmd-warm.mjs` delete the line `await runSearch.startDaemon?.();` (it exists only to keep the import used; remove the `runSearch` import too). The final `runSearchRefresh` catch block is:

```js
  } catch {
    const { startDaemonForWarm } = await import('./qmd-search.mjs');
    await startDaemonForWarm();
    await call();
  }
```

- [ ] **Step 4: Add the hook entry points**

```bash
# shared/hooks/scripts/qmd-warm.sh
#!/usr/bin/env bash
# SessionStart: warm the QMD index and daemon in the background; never blocks or fails the session.
script="$HOME/.my-ai-configuration/qmd/qmd-warm.mjs"
if [ -f "$script" ] && command -v node >/dev/null 2>&1 && git rev-parse --show-toplevel >/dev/null 2>&1; then
  nohup node "$script" >/dev/null 2>&1 &
fi
exit 0
```

```powershell
# shared/hooks/scripts/Start-QmdWarm.ps1
# SessionStart: warm the QMD index and daemon in the background; never blocks or fails the session.
$ErrorActionPreference = 'SilentlyContinue'
$script = Join-Path $HOME '.my-ai-configuration/qmd/qmd-warm.mjs'
$node = Get-Command node -ErrorAction SilentlyContinue
if ((Test-Path -LiteralPath $script) -and $node) {
    $null = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0) {
        Start-Process -FilePath $node.Source -ArgumentList @("`"$script`"") -WindowStyle Hidden -WorkingDirectory (Get-Location).Path
    }
}
exit 0
```

- [ ] **Step 5: Register the hooks in the adapters**

`adapters/claude/config/settings.json`, replace the `SessionStart` line with:

```json
    "SessionStart": [
      {"hooks": [{"type": "command", "command": "__HOOK_COMMAND__ \"__AI_CONFIG_ROOT__/hooks/scripts/__SESSION_POINTER_SCRIPT__\"", "timeout": 4}]},
      {"hooks": [{"type": "command", "command": "__HOOK_COMMAND__ \"__AI_CONFIG_ROOT__/hooks/scripts/__QMD_WARM_SCRIPT__\"", "timeout": 4}]}
    ],
```

`adapters/codex/config/config.toml`, replace the `writable_roots` line and append the hook:

```toml
writable_roots = ['__AI_CONFIG_ROOT__/../.my-ai-configuration/qmd', '__AI_CONFIG_ROOT__/../.cache/qmd']
```

```toml
[[hooks.SessionStart]]
[[hooks.SessionStart.hooks]]
type = "command"
command = '__HOOK_COMMAND__ "__AI_CONFIG_ROOT__/hooks/scripts/qmd-warm.sh"'
command_windows = '__POWERSHELL_HOOK_COMMAND__ "__AI_CONFIG_ROOT__/hooks/scripts/Start-QmdWarm.ps1"'
timeout = 4
```

Substitute `__QMD_WARM_SCRIPT__` wherever `__SESSION_POINTER_SCRIPT__` is substituted today (find it with `rg -n "__SESSION_POINTER_SCRIPT__" scripts`): `qmd-warm.sh` for Bash packages, `Start-QmdWarm.ps1` for PowerShell packages, mirroring the existing pair `show-session-state-pointer.sh` / `Show-SessionStatePointer.ps1`.

- [ ] **Step 6: Extend the install-time filter**

In `scripts/lib/install-options.py`:

```python
def is_qmd_warm(hook):
    return any(re.search(r'(?:qmd-warm\.sh|Start-QmdWarm\.ps1)', str(hook.get(key, '')), re.I)
               for key in ('command', 'command_windows'))


def without_hooks(groups, predicate):
    remaining = []
    for group in groups:
        hooks = [hook for hook in group.get('hooks', []) if not predicate(hook)]
        if hooks:
            remaining.append(dict(group, hooks=hooks))
    return remaining


def filter_instructions(text, semantic_retrieval_enabled):
    if semantic_retrieval_enabled:
        return text
    return ''.join(line for line in text.splitlines(keepends=True) if '`semantic-search`' not in line)
```

Change the signature to `def filter_options(path, flashbang_enabled=True, statusline_enabled=True, semantic_retrieval_enabled=True):`. In the `settings.json` branch, after the flashbang block, add:

```python
        if not semantic_retrieval_enabled:
            remaining = without_hooks(settings.get('hooks', {}).get('SessionStart', []), is_qmd_warm)
            if remaining:
                settings['hooks']['SessionStart'] = remaining
            else:
                settings.get('hooks', {}).pop('SessionStart', None)
```

In the `config.toml` branch, after the flashbang block, add:

```python
    if not semantic_retrieval_enabled:
        sections = re.split(r'(?m)(?=^\s*\[\[?[^\r\n]+\]\]?\s*$)', result)
        kept = []
        for section in sections:
            if re.match(r'\s*\[\[hooks\.SessionStart\.hooks\]\]', section):
                hook = tomllib.loads(section)['hooks']['SessionStart']['hooks'][0]
                if is_qmd_warm(hook):
                    continue
            kept.append(section)
        result = ''.join(kept)
        result = re.sub(r'(?m)^\[\[hooks\.SessionStart\]\][ \t]*\r?\n\s*(?=\[|\Z)(?!\[\[hooks\.SessionStart\.hooks\]\])', '', result)
```

Add `--semantic-retrieval true|false` to the existing `filter` subcommand's argument parser and pass it through. Add a `filter-instructions --path <file> --semantic-retrieval true|false` subcommand printing `filter_instructions(...)`.

- [ ] **Step 7: Pass the flag from the managed sync**

`scripts/lib/manifest.sh` (inside the loop around line 208): extend the filter condition and call:

```bash
    if { [ "$flashbang_enabled" = false ] || [ "$statusline_enabled" = false ] || [ "$semantic_retrieval_enabled" = false ]; } && [[ "$relative" = settings.json || "$relative" = config.toml ]]; then
      content=$(python3 "$(dirname -- "${BASH_SOURCE[0]}")/install-options.py" filter --path "$source_file" --flashbang "$flashbang_enabled" --statusline "$statusline_enabled" --semantic-retrieval "$semantic_retrieval_enabled" && printf '\034') || return
      content=${content%$'\034'}
      needs_sub=true
    fi
    if [ "$semantic_retrieval_enabled" = false ] && [[ "$relative" = CLAUDE.md || "$relative" = AGENTS.md ]]; then
      content=$(python3 "$(dirname -- "${BASH_SOURCE[0]}")/install-options.py" filter-instructions --path "$source_file" --semantic-retrieval false && printf '\034') || return
      content=${content%$'\034'}
      needs_sub=true
    fi
```

`scripts/lib/manifest.ps1`: make the equivalent change where it calls `install-options.py filter` (pass `--semantic-retrieval $SemanticRetrievalEnabled.ToString().ToLowerInvariant()`), and add the same `filter-instructions` call for `CLAUDE.md` / `AGENTS.md` when `-not $SemanticRetrievalEnabled`.

- [ ] **Step 8: Run tests to verify they pass**

Run: `node --test scripts/tests/test-qmd-warm.mjs` → PASS, 2 tests.
Run: `python scripts/tests/test-install-options.py` → PASS.
Run: `bash scripts/tests/test-managed-install.sh --summary` and `pwsh -NoProfile -File scripts/tests/test-managed-install.ps1 -Summary` → PASS.

- [ ] **Step 9: Commit**

```bash
git add shared/qmd/qmd-warm.mjs shared/qmd/qmd-search.mjs shared/hooks/scripts/qmd-warm.sh shared/hooks/scripts/Start-QmdWarm.ps1 \
  adapters/claude/config/settings.json adapters/codex/config/config.toml scripts/lib/install-options.py scripts/lib/manifest.sh scripts/lib/manifest.ps1 \
  scripts/tests/test-qmd-warm.mjs scripts/tests/test-install-options.py
git commit -m "feat(qmd): warm the index and daemon from a SessionStart hook"
```

---

### Task 5: Auto benchmark (`qmd-benchmark.mjs`)

**Files:**
- Create: `shared/qmd/qmd-benchmark.mjs`
- Test: `scripts/tests/test-qmd-benchmark.mjs`

**Interfaces:**
- Consumes: `MODELS`, `deviceEnv`, `importQmd`, `qmdPackageDir` (Task 1).
- Produces:
  - `node qmd-benchmark.mjs --detect` → stdout `{"gpu": "cuda"|"vulkan"|"metal"|false, "devices": [GPU names], "threads": <logical cores>}`
  - `node qmd-benchmark.mjs --device gpu|cpu` → stdout `{"device", "querySeconds", "chunksPerSecond", "passed"}`; process env must already carry `deviceEnv(device)` (the Python caller sets it).
  - Exported `passes({querySeconds, chunksPerSecond}, env): boolean`, `fixtureDocuments(count): Array<{name, text}>`, `describeDevices({gpu, devices, threads}): string`.

- [ ] **Step 1: Write the failing tests**

```js
// scripts/tests/test-qmd-benchmark.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { passes, fixtureDocuments, describeDevices } from '../../shared/qmd/qmd-benchmark.mjs';

test('both thresholds must pass', () => {
  assert.equal(passes({ querySeconds: 5, chunksPerSecond: 20 }, {}), true);
  assert.equal(passes({ querySeconds: 5.01, chunksPerSecond: 50 }, {}), false);
  assert.equal(passes({ querySeconds: 1, chunksPerSecond: 19.9 }, {}), false);
});

test('thresholds are overridable', () => {
  assert.equal(passes({ querySeconds: 8, chunksPerSecond: 5 }, { QMD_BENCHMARK_MAX_QUERY_SECONDS: '10', QMD_BENCHMARK_MIN_CHUNKS_PER_SECOND: '4' }), true);
});

test('device description lists every GPU and the thread count', () => {
  assert.equal(describeDevices({ gpu: 'cuda', devices: ['RTX 4090', 'RTX 3090'], threads: 64 }), 'CUDA: RTX 4090, RTX 3090; CPU threads: 64');
  assert.equal(describeDevices({ gpu: false, devices: [], threads: 16 }), 'no GPU; CPU threads: 16');
});

test('fixture is deterministic and large enough for throughput', () => {
  const a = fixtureDocuments(100);
  assert.equal(a.length, 100);
  assert.deepEqual(a, fixtureDocuments(100));
  assert.ok(a.every((d) => d.text.length > 2500));
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `node --test scripts/tests/test-qmd-benchmark.mjs`
Expected: FAIL (module missing).

- [ ] **Step 3: Implement `qmd-benchmark.mjs`**

```js
// shared/qmd/qmd-benchmark.mjs — measures warm QMD search latency and embedding throughput on one device.
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { availableParallelism, tmpdir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';
import { MODELS, importQmd, qmdPackageDir } from './qmd-lib.mjs';

export function passes({ querySeconds, chunksPerSecond }, env = process.env) {
  const maxQuery = Number(env.QMD_BENCHMARK_MAX_QUERY_SECONDS) || 5;
  const minChunks = Number(env.QMD_BENCHMARK_MIN_CHUNKS_PER_SECOND) || 20;
  return querySeconds <= maxQuery && chunksPerSecond >= minChunks;
}

const TOPICS = ['invoice rounding', 'upload retries', 'trial expiry', 'cache invalidation', 'session tokens'];

export function fixtureDocuments(count) {
  return Array.from({ length: count }, (_, index) => {
    const topic = TOPICS[index % TOPICS.length];
    const sections = Array.from({ length: 6 }, (__, section) =>
      `## ${topic} part ${section}\n\nThis section ${index}-${section} explains how ${topic} behaves when the service handles request ${index * 7 + section}. ` +
      `It lists the edge cases, the configuration keys, and the error messages that operators see during incidents.\n`.repeat(2));
    return { name: `doc-${String(index).padStart(3, '0')}.md`, text: `# ${topic} ${index}\n\n${sections.join('\n')}` };
  });
}

export function describeDevices({ gpu, devices, threads }) {
  const gpus = gpu ? `${String(gpu).toUpperCase()}: ${devices.join(', ') || 'unnamed device'}` : 'no GPU';
  return `${gpus}; CPU threads: ${threads}`;
}

// llama.cpp's automatic backend uses every GPU of the chosen backend; nothing here narrows the device set.
async function detect() {
  const { getLlama } = await import(pathToFileURL(join(qmdPackageDir(), 'node_modules', 'node-llama-cpp', 'dist', 'index.js')).href);
  const llama = await getLlama({ gpu: 'auto' });
  const gpu = llama.gpu;
  const devices = gpu ? await llama.getGpuDeviceNames() : [];
  await llama.dispose();
  return { gpu, devices, threads: availableParallelism() };
}

async function measure(device) {
  for (const [key, value] of Object.entries({ QMD_EMBED_MODEL: MODELS.embed, QMD_RERANK_MODEL: MODELS.rerank, QMD_GENERATE_MODEL: MODELS.generate })) {
    process.env[key] = value;
  }
  const work = mkdtempSync(join(tmpdir(), 'ai-config-qmd-bench-'));
  try {
    const docs = join(work, 'docs');
    mkdirSync(docs);
    for (const doc of fixtureDocuments(100)) writeFileSync(join(docs, doc.name), doc.text);
    const { createStore } = await importQmd();
    const store = await createStore({ dbPath: join(work, 'index.sqlite'), config: { collections: { bench: { path: docs, pattern: '**/*.md' } } } });
    try {
      await store.update();
      await store.searchVector('warm up the embedding model', { limit: 1 });
      const embedded = await store.embed({ collection: 'bench' });
      const chunksPerSecond = embedded.chunksEmbedded / Math.max(embedded.durationMs / 1000, 0.001);
      const question = 'Which part explains how upload retries behave during incidents?';
      await store.search({ query: question, collections: ['bench'], limit: 5 });
      const times = [];
      for (let run = 0; run < 3; run += 1) {
        const started = performance.now();
        await store.search({ query: `${question} (${run})`, collections: ['bench'], limit: 5, candidateLimit: 40 });
        times.push((performance.now() - started) / 1000);
      }
      const querySeconds = times.sort((a, b) => a - b)[1];
      const result = { device, querySeconds: Number(querySeconds.toFixed(3)), chunksPerSecond: Number(chunksPerSecond.toFixed(1)) };
      return { ...result, passed: passes(result) };
    } finally {
      await store.close();
    }
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
}

async function main() {
  const { values } = parseArgs({ options: { detect: { type: 'boolean' }, device: { type: 'string' } } });
  if (values.detect) return console.log(JSON.stringify(await detect()));
  if (!['gpu', 'cpu'].includes(values.device)) throw new Error('--device gpu|cpu or --detect is required');
  console.log(JSON.stringify(await measure(values.device)));
}

if (import.meta.url === pathToFileURL(process.argv[1] || '').href) {
  main().catch((error) => { console.error(`qmd-benchmark: ${error.message}`); process.exit(1); });
}
```

Each query in the measured loop has a distinct suffix so QMD's expansion cache cannot hide model latency.

- [ ] **Step 4: Run tests to verify they pass**

Run: `node --test scripts/tests/test-qmd-benchmark.mjs`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add shared/qmd/qmd-benchmark.mjs scripts/tests/test-qmd-benchmark.mjs
git commit -m "feat(qmd): add GPU and CPU benchmark for Auto selection"
```

---

### Task 6: Installer library (`scripts/lib/qmd.py` with Bash and PowerShell wrappers)

**Files:**
- Create: `scripts/lib/qmd.py`, `scripts/lib/qmd.sh`, `scripts/lib/qmd.ps1`
- Test: `scripts/tests/test-qmd-setup.py`

**Interfaces:**
- Consumes: Node scripts from Tasks 1–5 (copied from `shared/qmd/`).
- Produces:
  - `python scripts/lib/qmd.py sync --root R --home H --client codex|claude|both --enabled true|false [--dry-run] [--update] [--summary]` → exit 0/1.
  - `python scripts/lib/qmd.py benchmark --root R --home H [--summary]` → exit 0 (suitable; device stored), 2 (unsuitable; everything setup-owned removed), 1 (error).
  - Bash: `sync_qmd <root> <client> <home> <enabled> <dry-run> <update> [summary]`, `test_qmd_device <root> <home> [summary]` (returns 0 suitable, 1 unsuitable, 2 error).
  - PowerShell: `Sync-Qmd -RepositoryRoot -HomePath -Client -Enabled [-DryRun] [-Update] [-Summary]`, `Test-QmdDevice -RepositoryRoot -HomePath [-Summary]` → `$true`/`$false`, throws on error.
  - Python functions (tested): `decide(results: list[dict]) -> str | None`, `node_version_ok(text: str) -> bool`, `class Setup(home, root, run, dry_run, summary)` with `enable(clients)`, `disable(clients)`, `benchmark() -> bool`, `migrate()`.
  - State `qmd.json`: `{"version": 1, "clients": [...], "device": "gpu"|"cpu"|null, "owned_package": bool, "owned_models": [file names], "models_block": bool, "files": {name: sha256}}`.

- [ ] **Step 1: Write the failing tests**

```python
# scripts/tests/test-qmd-setup.py
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('qmd_setup', ROOT / 'scripts/lib/qmd.py')
qmd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qmd)


class FakeRunner:
    def __init__(self, installed=False, gpu='cuda', gpu_result=None, cpu_result=None):
        self.calls, self.installed, self.gpu = [], installed, gpu
        self.results = {'gpu': gpu_result, 'cpu': cpu_result}

    def __call__(self, arguments, env=None, timeout=None):
        self.calls.append(list(arguments))
        joined = ' '.join(arguments)
        if arguments[:2] == ['node', '--version']:
            return 'v22.4.0'
        if 'npm list' in joined:
            return json.dumps({'dependencies': {'@tobilu/qmd': {}} if self.installed else {}})
        if 'npm install' in joined:
            self.installed = True
        if 'npm uninstall' in joined:
            self.installed = False
        if '--detect' in joined:
            return json.dumps({'gpu': self.gpu, 'devices': ['GPU 0', 'GPU 1'] if self.gpu else [], 'threads': 32})
        if '--device' in joined:
            device = arguments[arguments.index('--device') + 1]
            return json.dumps(self.results[device])
        return ''


class SetupTest(unittest.TestCase):
    def setUp(self):
        self.home = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.home, ignore_errors=True)
        (self.home / '.cache/qmd/models').mkdir(parents=True)

    def setup(self, runner, dry_run=False):
        return qmd.Setup(self.home, ROOT, runner, dry_run=dry_run, summary=True)

    def state(self):
        return json.loads((self.home / '.my-ai-configuration/qmd.json').read_text(encoding='utf-8'))

    def test_decide_prefers_gpu_then_cpu(self):
        self.assertEqual(qmd.decide([{'device': 'gpu', 'passed': True}, {'device': 'cpu', 'passed': True}]), 'gpu')
        self.assertEqual(qmd.decide([{'device': 'gpu', 'passed': False}, {'device': 'cpu', 'passed': True}]), 'cpu')
        self.assertIsNone(qmd.decide([{'device': 'gpu', 'passed': False}, {'device': 'cpu', 'passed': False}]))
        self.assertIsNone(qmd.decide([]))

    def test_node_version(self):
        self.assertTrue(qmd.node_version_ok('v22.0.0'))
        self.assertFalse(qmd.node_version_ok('v20.11.1'))
        self.assertFalse(qmd.node_version_ok('garbage'))

    def test_enable_installs_package_scripts_and_records_ownership(self):
        runner = FakeRunner()
        self.setup(runner).enable(['claude'])
        state = self.state()
        self.assertTrue(state['owned_package'])
        self.assertEqual(state['device'], 'gpu')
        self.assertTrue(state['models_block'])
        self.assertTrue((self.home / '.my-ai-configuration/qmd/qmd-search.mjs').is_file())
        self.assertIn(['npm', 'install', '--global', '@tobilu/qmd@2.8.3'], runner.calls)

    def test_enable_keeps_foreign_package_unowned(self):
        runner = FakeRunner(installed=True)
        self.setup(runner).enable(['claude'])
        self.assertFalse(self.state()['owned_package'])
        self.assertFalse(any('npm install' in ' '.join(c) for c in runner.calls))

    def test_disable_never_removes_foreign_package(self):
        runner = FakeRunner(installed=True)
        setup = self.setup(runner)
        setup.enable(['claude'])
        setup.disable(['claude'])
        self.assertFalse(any('npm uninstall' in ' '.join(c) for c in runner.calls))
        self.assertFalse((self.home / '.my-ai-configuration/qmd.json').exists())

    def test_disable_removes_owned_models_and_collections(self):
        runner = FakeRunner()
        setup = self.setup(runner)
        setup.enable(['claude'])
        state = self.state()
        model = self.home / '.cache/qmd/models' / 'qwen3-embedding.gguf'
        model.write_text('x')
        state['owned_models'] = ['qwen3-embedding.gguf']
        (self.home / '.my-ai-configuration/qmd.json').write_text(json.dumps(state))
        (self.home / '.my-ai-configuration/qmd/collections.json').write_text(json.dumps(['repo-abcdefabcdef']))
        setup.disable(['claude'])
        self.assertFalse(model.exists())
        self.assertIn(['qmd', 'collection', 'remove', 'repo-abcdefabcdef'], runner.calls)
        self.assertIn(['npm', 'uninstall', '--global', '@tobilu/qmd'], runner.calls)

    def test_benchmark_unsuitable_cleans_up(self):
        runner = FakeRunner(gpu=False, cpu_result={'device': 'cpu', 'passed': False, 'querySeconds': 9, 'chunksPerSecond': 3})
        self.assertFalse(self.setup(runner).benchmark())
        self.assertFalse((self.home / '.my-ai-configuration/qmd.json').exists())
        self.assertIn(['npm', 'uninstall', '--global', '@tobilu/qmd'], runner.calls)
        self.assertFalse(any('--device' in c and 'gpu' in c for c in runner.calls), 'no GPU means no GPU run')

    def test_benchmark_falls_back_to_cpu(self):
        runner = FakeRunner(gpu='vulkan', gpu_result={'device': 'gpu', 'passed': False, 'querySeconds': 7, 'chunksPerSecond': 30},
                            cpu_result={'device': 'cpu', 'passed': True, 'querySeconds': 4, 'chunksPerSecond': 25})
        self.assertTrue(self.setup(runner).benchmark())
        self.assertEqual(self.state()['device'], 'cpu')

    def test_migration_removes_python_retrieval_and_adopts_ledger_package(self):
        base = self.home / '.my-ai-configuration'
        (base / 'semantic-retrieval/.venv').mkdir(parents=True)
        (base / 'semantic-retrieval.json').write_text('{"version": 1, "clients": [], "files": {}}')
        (base / 'extensions.json').write_text(json.dumps({'version': 1, 'resources': [
            {'client': 'shared', 'name': 'QMD', 'kind': 'qmd', 'package': '@tobilu/qmd', 'clients': ['codex']},
            {'client': 'claude', 'name': 'QMD', 'kind': 'plugin', 'selector': 'qmd@qmd'}]}))
        runner = FakeRunner(installed=True)
        self.setup(runner).enable(['claude'])
        self.assertFalse((base / 'semantic-retrieval').exists())
        self.assertFalse((base / 'semantic-retrieval.json').exists())
        ledger = json.loads((base / 'extensions.json').read_text())
        self.assertEqual([r['kind'] for r in ledger['resources']], ['plugin'], 'plugin record stays so reconcile uninstalls qmd@qmd')
        self.assertTrue(self.state()['owned_package'], 'ledger-owned package is adopted')

    def test_dry_run_changes_nothing(self):
        runner = FakeRunner()
        self.setup(runner, dry_run=True).enable(['claude'])
        self.assertFalse((self.home / '.my-ai-configuration/qmd.json').exists())
        self.assertFalse(any('npm install' in ' '.join(c) for c in runner.calls))


if __name__ == '__main__':
    unittest.main()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python scripts/tests/test-qmd-setup.py`
Expected: FAIL with `FileNotFoundError` for `scripts/lib/qmd.py`.

- [ ] **Step 3: Implement `scripts/lib/qmd.py`**

```python
"""Install, benchmark, migrate, and remove the setup-owned QMD local search."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

PACKAGE = '@tobilu/qmd'
VERSION = '2.8.3'
SCRIPTS = ('qmd-lib.mjs', 'qmd-config.mjs', 'qmd-daemon.mjs', 'qmd-search.mjs', 'qmd-warm.mjs', 'qmd-benchmark.mjs')
DEVICE_TIMEOUT = 600
WINDOWS = os.name == 'nt'


def run(arguments, env=None, timeout=1800):
    result = subprocess.run(arguments, env=env, capture_output=True, text=True, encoding='utf-8', errors='replace',
                            timeout=timeout, shell=WINDOWS and arguments[0] in ('npm', 'qmd'))
    if result.returncode != 0:
        raise ValueError(f'{" ".join(arguments[:3])} failed: {(result.stderr or result.stdout).strip()[-300:]}')
    return result.stdout


def decide(results):
    for device in ('gpu', 'cpu'):
        if any(r.get('device') == device and r.get('passed') is True for r in results):
            return device
    return None


def node_version_ok(text):
    match = re.fullmatch(r'v(\d+)\.\d+\.\d+', text.strip())
    return bool(match) and int(match.group(1)) >= 22


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', dir=path.parent, delete=False) as stream:
        json.dump(value, stream, indent=2)
        stream.write('\n')
    os.replace(stream.name, path)


class Setup:
    def __init__(self, home, root, runner=run, dry_run=False, summary=False):
        self.home, self.root, self.run, self.dry_run, self.summary = Path(home), Path(root), runner, dry_run, summary
        self.base = self.home / '.my-ai-configuration'
        self.state_path = self.base / 'qmd.json'
        self.scripts = self.base / 'qmd'
        self.models = self.home / '.cache' / 'qmd' / 'models'

    def say(self, text):
        if not self.summary:
            print(text)

    def load(self):
        if not self.state_path.exists():
            return {'version': 1, 'clients': [], 'device': None, 'owned_package': False, 'owned_models': [], 'models_block': False, 'files': {}}
        state = json.loads(self.state_path.read_text(encoding='utf-8'))
        if state.get('version') != 1 or state.get('device') not in (None, 'gpu', 'cpu'):
            raise ValueError('Invalid QMD setup state.')
        return state

    def node(self, script, *arguments, env=None, timeout=1800):
        return self.run(['node', str(self.scripts / script), *arguments], env=env, timeout=timeout)

    def package_installed(self):
        listing = json.loads(self.run(['npm', 'list', '--global', '--depth=0', '--json']) or '{}')
        return PACKAGE in (listing.get('dependencies') or {})

    def require_node(self):
        if not node_version_ok(self.run(['node', '--version'])):
            raise ValueError('QMD local search needs Node.js 22 or newer.')

    def migrate(self, state):
        legacy_state = self.base / 'semantic-retrieval.json'
        legacy = self.base / 'semantic-retrieval'
        if legacy_state.exists() or legacy.exists():
            if legacy.is_symlink():
                raise ValueError('Legacy semantic retrieval directory must not be a symbolic link.')
            shutil.rmtree(legacy, ignore_errors=True)
            legacy_state.unlink(missing_ok=True)
            self.say('Removed the previous Python semantic retrieval installation.')
        ledger_path = self.base / 'extensions.json'
        if ledger_path.exists():
            ledger = json.loads(ledger_path.read_text(encoding='utf-8'))
            owned = [r for r in ledger.get('resources', []) if r.get('kind') == 'qmd']
            if owned:
                ledger['resources'] = [r for r in ledger['resources'] if r.get('kind') != 'qmd']
                atomic_json(ledger_path, ledger)
                state['owned_package'] = True

    def install_scripts(self, state):
        self.scripts.mkdir(parents=True, exist_ok=True)
        for name in SCRIPTS:
            target = self.scripts / name
            expected = state['files'].get(name)
            if target.exists() and expected and digest(target) != expected:
                raise ValueError(f'Setup-owned QMD script changed: {name}')
            shutil.copy2(self.root / 'shared' / 'qmd' / name, target)
            state['files'][name] = digest(target)

    def install(self, state):
        """Steps shared by Yes and Auto: package, scripts, models block, model download."""
        self.require_node()
        self.migrate(state)
        if not self.package_installed():
            self.run(['npm', 'install', '--global', f'{PACKAGE}@{VERSION}'])
            state['owned_package'] = True
        self.install_scripts(state)
        atomic_json(self.state_path, state)
        if not state['models_block']:
            self.node('qmd-config.mjs', 'set-models')
            state['models_block'] = True
            atomic_json(self.state_path, state)
        before = {p.name for p in self.models.iterdir()} if self.models.is_dir() else set()
        self.run(['qmd', 'pull'], timeout=3600)
        after = {p.name for p in self.models.iterdir()} if self.models.is_dir() else set()
        state['owned_models'] = sorted(set(state['owned_models']) | (after - before))
        atomic_json(self.state_path, state)

    def detect_gpu(self):
        found = json.loads(self.node('qmd-benchmark.mjs', '--detect', timeout=DEVICE_TIMEOUT) or '{}')
        gpu = found.get('gpu') or False
        names = ', '.join(found.get('devices') or []) or 'unnamed device'
        print(f"QMD devices: {f'{str(gpu).upper()}: {names}' if gpu else 'no GPU'}; CPU threads: {found.get('threads', '?')}")
        return gpu

    def enable(self, clients):
        state = self.load()
        if self.dry_run:
            self.say('DRYRUN enable QMD local search: Qwen3-Embedding-0.6B, Qwen3-Reranker-0.6B, QMD query expansion 1.7B')
            return
        self.install(state)
        if state['device'] is None:
            state['device'] = 'gpu' if self.detect_gpu() else 'cpu'
        state['clients'] = sorted(set(state['clients']) | set(clients))
        atomic_json(self.state_path, state)
        self.say(f'QMD local search enabled on {state["device"].upper()}.')

    def remove_all(self, state):
        try:
            if self.scripts.joinpath('qmd-search.mjs').exists():
                self.node('qmd-search.mjs', '--stop', timeout=60)
        except (ValueError, subprocess.SubprocessError):
            pass
        collections = self.scripts / 'collections.json'
        names = json.loads(collections.read_text(encoding='utf-8')) if collections.exists() else []
        for name in names:
            if re.fullmatch(r'repo-[0-9a-f]{12}', name):
                try:
                    self.run(['qmd', 'collection', 'remove', name])
                except ValueError:
                    pass
        if state['models_block'] and self.scripts.joinpath('qmd-config.mjs').exists():
            self.node('qmd-config.mjs', 'unset-models')
        for name in state['owned_models']:
            path = self.models / name
            if path.is_file() and not path.is_symlink():
                path.unlink()
        if state['owned_package']:
            self.run(['npm', 'uninstall', '--global', PACKAGE])
        if self.scripts.exists() and not self.scripts.is_symlink():
            shutil.rmtree(self.scripts)
        self.state_path.unlink(missing_ok=True)

    def disable(self, clients):
        state = self.load()
        if not self.state_path.exists():
            if not self.dry_run:
                self.migrate(state)
            return
        if self.dry_run:
            self.say('DRYRUN disable QMD local search')
            return
        state['clients'] = [c for c in state['clients'] if c not in clients]
        if state['clients']:
            atomic_json(self.state_path, state)
            return
        self.remove_all(state)
        self.say('QMD local search removed.')

    def benchmark(self):
        state = self.load()
        if self.dry_run:
            self.say('DRYRUN benchmark QMD local search on GPU, then CPU')
            return True
        self.install(state)
        results = []
        devices = (['gpu'] if self.detect_gpu() else []) + ['cpu']
        for device in devices:
            env = dict(os.environ)
            env.pop('QMD_FORCE_CPU' if device == 'gpu' else 'QMD_LLAMA_GPU', None)
            env['QMD_LLAMA_GPU' if device == 'gpu' else 'QMD_FORCE_CPU'] = 'auto' if device == 'gpu' else '1'
            try:
                result = json.loads(self.node('qmd-benchmark.mjs', '--device', device, env=env, timeout=DEVICE_TIMEOUT))
            except (ValueError, subprocess.TimeoutExpired) as error:
                result = {'device': device, 'passed': False, 'error': str(error)[:200]}
            results.append(result)
            print(f'QMD benchmark {device.upper()}: ' + ('passed' if result.get('passed') else 'failed')
                  + f" (search {result.get('querySeconds', '-')} s, embedding {result.get('chunksPerSecond', '-')} chunks/s)")
            if result.get('passed'):
                break
        device = decide(results)
        if device is None:
            self.remove_all(state)
            print('QMD local search is not suitable for this computer; removed what the setup installed.')
            return False
        state['device'] = device
        atomic_json(self.state_path, state)
        return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('sync', 'benchmark'))
    parser.add_argument('--root', required=True, type=Path)
    parser.add_argument('--home', required=True, type=Path)
    parser.add_argument('--client', choices=('codex', 'claude', 'both'))
    parser.add_argument('--enabled', choices=('true', 'false'))
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--update', action='store_true')
    parser.add_argument('--summary', action='store_true')
    args = parser.parse_args()
    setup = Setup(args.home.resolve(), args.root.resolve(), run, args.dry_run, args.summary)
    if args.action == 'benchmark':
        raise SystemExit(0 if setup.benchmark() else 2)
    if args.client is None or args.enabled is None:
        parser.error('sync requires --client and --enabled')
    clients = ['codex', 'claude'] if args.client == 'both' else [args.client]
    (setup.enable if args.enabled == 'true' else setup.disable)(clients)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, json.JSONDecodeError, subprocess.SubprocessError) as error:
        print(f'QMD local search: {error}', file=sys.stderr)
        raise SystemExit(1)
```

- [ ] **Step 4: Add the shell wrappers**

```bash
# scripts/lib/qmd.sh
#!/usr/bin/env bash

sync_qmd() {
  local root=$1 client=$2 home_path=$3 enabled=$4 dry_run=$5 update=$6 summary=${7:-false}
  local arguments=("$root/scripts/lib/qmd.py" sync --root "$root" --home "$home_path" --client "$client" --enabled "$enabled")
  [ "$dry_run" != true ] || arguments+=(--dry-run)
  [ "$update" != true ] || arguments+=(--update)
  [ "$summary" != true ] || arguments+=(--summary)
  python3 "${arguments[@]}"
}

test_qmd_device() {
  local root=$1 home_path=$2 summary=${3:-false}
  local arguments=("$root/scripts/lib/qmd.py" benchmark --root "$root" --home "$home_path")
  [ "$summary" != true ] || arguments+=(--summary)
  local status
  if python3 "${arguments[@]}" >&2; then return 0; else status=$?; fi
  [ "$status" -eq 2 ] && return 1
  return 2
}
```

```powershell
# scripts/lib/qmd.ps1
function Sync-Qmd {
    param([Parameter(Mandatory=$true)][string]$RepositoryRoot,[Parameter(Mandatory=$true)][string]$HomePath,[ValidateSet('Codex','Claude','Both')][Parameter(Mandatory=$true)][string]$Client,[Parameter(Mandatory=$true)][bool]$Enabled,[switch]$DryRun,[switch]$Update,[switch]$Summary)
    $arguments = @((Join-Path $PSScriptRoot 'qmd.py'), 'sync', '--root', $RepositoryRoot, '--home', $HomePath, '--client', $Client.ToLowerInvariant(), '--enabled', $Enabled.ToString().ToLowerInvariant())
    if ($DryRun) { $arguments += '--dry-run' }; if ($Update) { $arguments += '--update' }
    if ($Summary) { $arguments += '--summary' }
    & python @arguments
    if ($LASTEXITCODE -ne 0) { throw 'QMD local search reconciliation failed.' }
}

function Test-QmdDevice {
    param([Parameter(Mandatory=$true)][string]$RepositoryRoot,[Parameter(Mandatory=$true)][string]$HomePath,[switch]$Summary)
    & python (Join-Path $PSScriptRoot 'qmd.py') benchmark --root $RepositoryRoot --home $HomePath $(if ($Summary) { '--summary' }) | Write-Host
    if ($LASTEXITCODE -eq 0) { return $true }
    if ($LASTEXITCODE -eq 2) { return $false }
    throw 'QMD benchmark failed.'
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `python scripts/tests/test-qmd-setup.py`
Expected: PASS, 10 tests. Fix only `qmd.py` if a test fails; the tests encode the spec.

- [ ] **Step 6: Commit**

```bash
git add scripts/lib/qmd.py scripts/lib/qmd.sh scripts/lib/qmd.ps1 scripts/tests/test-qmd-setup.py
git commit -m "feat(qmd): install, benchmark, migrate, and remove QMD local search"
```

---

### Task 7: Wire the installer into install, update, and uninstall

**Files:**
- Modify: `scripts/lib/install-options.sh:37-60`, `scripts/lib/install-options.ps1:27-45`
- Modify: `scripts/commands/install.sh`, `install.ps1`, `update.sh`, `update.ps1`, `uninstall.sh`, `uninstall.ps1`
- Test: `scripts/tests/test-install-guards.sh`, `scripts/tests/test-install-guards.ps1`

**Interfaces:**
- Consumes: `sync_qmd`, `test_qmd_device`, `Sync-Qmd`, `Test-QmdDevice` (Task 6).
- Produces: the prompt text `Enable local QMD search models (Qwen3 embedding, Qwen3 reranker, QMD query expansion)? [y/N/a]` (or `[Y/n/a]` when the stored default is true).

- [ ] **Step 1: Write the failing guard tests**

Add to `scripts/tests/test-install-guards.sh` (follow the file's existing helper style for temp homes and assertions):

```bash
# QMD prompt: Auto maps benchmark exit codes; No never calls the benchmark.
(
  root=$repo_root
  home_path=$(mktemp -d)
  . "$root/scripts/lib/install-options.sh"
  test_qmd_device() { return 1; }
  [ "$(printf 'a\n' | read_semantic_retrieval_option false 2>/dev/null)" = false ] || { echo 'Auto unsuitable must yield false' >&2; exit 1; }
  test_qmd_device() { return 0; }
  [ "$(printf 'a\n' | read_semantic_retrieval_option false 2>/dev/null)" = true ] || { echo 'Auto suitable must yield true' >&2; exit 1; }
  test_qmd_device() { echo 'must not run' >&2; exit 9; }
  [ "$(printf 'n\n' | read_semantic_retrieval_option true 2>/dev/null)" = false ] || { echo 'No must yield false' >&2; exit 1; }
  printf 'n\n' | read_semantic_retrieval_option true 2>&1 >/dev/null | grep -q 'Enable local QMD search models' || { echo 'prompt text changed' >&2; exit 1; }
)
```

Add the equivalent block to `scripts/tests/test-install-guards.ps1`, mocking `Test-QmdDevice` with a function returning `$false`/`$true` and feeding input through `[Console]::SetIn([IO.StringReader]::new("a`n"))`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash scripts/tests/test-install-guards.sh --summary`
Expected: FAIL with `prompt text changed` (and the Auto assertions, because the prompt still calls `test_semantic_retrieval_device`).

- [ ] **Step 3: Update the prompt in both shells**

`scripts/lib/install-options.sh`, in `read_semantic_retrieval_option`: change the prompt line and the Auto call:

```bash
    printf 'Enable local QMD search models (Qwen3 embedding, Qwen3 reranker, QMD query expansion)? [%s] ' "$hint" >&2
```

```bash
        if test_qmd_device "$root" "$home_path"; then printf 'true\n'; return; else status=$?; fi
```

`scripts/lib/install-options.ps1`, in `Read-SemanticRetrievalOption`: same prompt text; Auto branch becomes `return Test-QmdDevice -RepositoryRoot $RepositoryRoot -HomePath $HomePath`.

- [ ] **Step 4: Replace the retrieval calls in the commands**

In each of `install.sh`, `update.sh`, `uninstall.sh`:
- `. "$root/scripts/lib/semantic-retrieval.sh"` → `. "$root/scripts/lib/qmd.sh"`
- `sync_semantic_retrieval ...` → `sync_qmd ...` with the same arguments.
- In `install.sh` and `update.sh`, move the `sync_qmd` line so it runs **before** `sync_configured_plugins`, so a ledger-owned QMD package is adopted before the extension reconcile would uninstall it.

In each of `install.ps1`, `update.ps1`, `uninstall.ps1`:
- `. (Join-Path $root 'scripts/lib/semantic-retrieval.ps1')` → `. (Join-Path $root 'scripts/lib/qmd.ps1')`
- `Sync-SemanticRetrieval ...` → `Sync-Qmd ...` with the same arguments, placed before the plugin sync call in install and update.
- `uninstall.sh`/`.ps1` message: `semantic retrieval setup` → `QMD local search setup`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `bash scripts/tests/test-install-guards.sh --summary` → PASS.
Run: `pwsh -NoProfile -File scripts/tests/test-install-guards.ps1 -Summary` → PASS.
Run: `bash scripts/commands/install.sh --summary --dry-run --client both --shell bash` → output contains no `semantic retrieval` and ends with `Install: PASS`.

- [ ] **Step 6: Commit**

```bash
git add scripts/lib/install-options.sh scripts/lib/install-options.ps1 scripts/commands/install.sh scripts/commands/install.ps1 \
  scripts/commands/update.sh scripts/commands/update.ps1 scripts/commands/uninstall.sh scripts/commands/uninstall.ps1 \
  scripts/tests/test-install-guards.sh scripts/tests/test-install-guards.ps1
git commit -m "feat(install): ask for QMD local search models and run the QMD installer"
```

---

### Task 8: Remove the Python retrieval stack and the QMD extension

**Files:**
- Delete: `shared/retrieval/` (all files), `scripts/lib/semantic-retrieval.py`, `.sh`, `.ps1`, `scripts/tests/test-retrieval-server.py`, `scripts/tests/test-semantic-retrieval.py`
- Modify: `adapters/plugins.tsv` (delete the `QMD` row), `scripts/lib/managed-extensions.py` (drop `ensure_qmd` and the `codex_method == 'qmd'` branch; keep accepting `kind: qmd` records in `validate` so old ledgers still load), `scripts/lib/plugins.sh:164-165`, `scripts/lib/plugins.ps1` (QMD detection), `scripts/tests/test-managed-extensions.py` (remove QMD install cases; keep a case that an old `qmd` record still validates)
- Test: `scripts/tests/test-managed-extensions.py`, `scripts/tests/test-plugin-selection.sh`

**Interfaces:**
- Consumes: nothing new.
- Produces: the plugin selector no longer lists QMD.

- [ ] **Step 1: Write the failing test**

Add to `scripts/tests/test-managed-extensions.py`:

```python
    def test_manifest_has_no_qmd_extension(self):
        rows = (ROOT / 'adapters/plugins.tsv').read_text(encoding='utf-8').splitlines()
        self.assertFalse(any(row.split('\t')[0] == 'QMD' for row in rows[1:]))

    def test_legacy_qmd_record_still_validates(self):
        home = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, home, ignore_errors=True)
        (home / '.my-ai-configuration').mkdir()
        (home / '.my-ai-configuration/extensions.json').write_text(json.dumps({'version': 1, 'resources': [
            {'client': 'shared', 'name': 'QMD', 'kind': 'qmd', 'package': '@tobilu/qmd', 'clients': ['codex']}]}))
        module.ExtensionManager(home)  # must not raise
```

(Use the module alias, `ROOT`, and manager class name the file already defines; adapt only those identifiers.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `python scripts/tests/test-managed-extensions.py`
Expected: FAIL on `test_manifest_has_no_qmd_extension`.

- [ ] **Step 3: Remove code and files**

```bash
git rm -r shared/retrieval scripts/lib/semantic-retrieval.py scripts/lib/semantic-retrieval.sh scripts/lib/semantic-retrieval.ps1 \
  scripts/tests/test-retrieval-server.py scripts/tests/test-semantic-retrieval.py
```

Then edit: delete the `QMD` line from `adapters/plugins.tsv`; in `managed-extensions.py` delete `def ensure_qmd` and the `if entry['codex_method'] == 'qmd': self.ensure_qmd(client, entry)` branch (around line 307); delete the QMD branch in `plugins.sh` (lines 164-165) and its PowerShell equivalent in `plugins.ps1` (find with `rg -n "qmd" scripts/lib/plugins.ps1`); remove tests in `test-managed-extensions.py` that install QMD through `ensure_qmd`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `python scripts/tests/test-managed-extensions.py` → PASS.
Run: `bash scripts/tests/test-plugin-selection.sh --summary` → PASS.
Run: `rg -n -i "semantic-retrieval|shared/retrieval|ensure_qmd" -g '!generated' -g '!docs/superpowers' .` → no matches outside docs updated in Task 9.

- [ ] **Step 5: Commit**

```bash
git add -A adapters/plugins.tsv scripts/lib/managed-extensions.py scripts/lib/plugins.sh scripts/lib/plugins.ps1 scripts/tests/test-managed-extensions.py
git commit -m "refactor(retrieval): remove the Python Qwen stack and the QMD extension entry"
```

---

### Task 9: Strict skill, mandatory instruction line, documentation, prompt budget

**Files:**
- Modify: `shared/skills/research/semantic-search/SKILL.md` (rewrite)
- Modify: `shared/rules/general.md:9`
- Modify: `README.md`, `docs/plugins.md`, `docs/scripts.md`, `docs/skills.md`, `docs/hooks.md`
- Modify: `adapters/prompt-budget-baseline.json`, `adapters/prompt-budget-baseline.tsv` (after measuring)

**Interfaces:**
- Consumes: CLI of `qmd-search.mjs` (Task 3).
- Produces: skill name `semantic-search`, invocation `node "$HOME/.my-ai-configuration/qmd/qmd-search.mjs" --query "<question>" --top-k 5`.

- [ ] **Step 1: Rewrite the skill**

```markdown
---
name: semantic-search
description: MUST use before reading or grepping code whenever the exact symbol, file, or string is not already known - concept questions, unfamiliar areas, "where/how is X done", and bug reports that describe behavior. Use rg only for known identifiers, paths, or exact strings.
---

# Semantic Search

Search the current Git repository, plus the user's registered QMD collections, by meaning. QMD runs locally with Qwen3-Embedding-0.6B, Qwen3-Reranker-0.6B, and QMD Query Expansion 1.7B; a background daemon keeps them loaded.

## Rule

Run this search first whenever you do not already know the exact identifier, path, or string. Do not start with `rg` guesses for a concept. `rg` comes after the search, for callers and tests of verified hits.

## Run

The same command works in Bash and PowerShell:

    node "$HOME/.my-ai-configuration/qmd/qmd-search.mjs" --query "<full question about behavior>" --top-k 5

Output: JSON list of `{path, line, score, snippet}`, best first. Repository paths are relative to the repository root; hits from other collections are `qmd://<collection>/<path>`.

## Use the results

1. Phrase the query as a full question about behavior, not a keyword list.
2. Open the top hits and verify them against the current files before acting.
3. Follow verified hits with `rg` for their symbols to find callers and tests.
4. If no hit is relevant, run one rephrased search before switching to `rg`.

## Failure

If the command exits non-zero, continue with `rg` and state the limitation in one sentence.
```

- [ ] **Step 2: Make the instruction line mandatory and separate**

In `shared/rules/general.md`, replace the paragraph on line 9 with two lines (the second is removed at install time when the skill is disabled, see Task 4):

```markdown
Use direct reads and `rg` for known paths, symbols, exact strings, error messages, and localized edits.
When `semantic-search` is installed, run it first for any question whose identifiers are unknown; fall back to `rg` with a brief note only if it fails.
```

- [ ] **Step 3: Update documentation**

- `README.md` line 33: `Qwen retrieval` → `local QMD search models`. Line 102: replace with `Optional local search for both clients through QMD with Qwen3-Embedding-0.6B, Qwen3-Reranker-0.6B, and QMD Query Expansion 1.7B (Yes/No/Auto; Auto benchmarks GPU, then CPU).` Line 111: replace the Python venv prerequisite with `Node.js 22 or newer and npm when local QMD search is enabled.` Lines 235, 266, 292: replace `semantic retrieval` wording with `local QMD search`. Lines 99 and 112: remove QMD from the extension list and its Node prerequisite sentence.
- `docs/plugins.md`: remove QMD from the baseline list and delete the QMD paragraph (line 19); replace lines 21-23 with a paragraph describing the question, Auto thresholds (search ≤ 5 s, embedding ≥ 20 chunks/s, GPU then CPU), the daemon (loopback, token, 30-minute idle exit), the SessionStart warm-up, ownership-only removal, and migration from the Python stack.
- `docs/scripts.md`: replace rows for `lib/semantic-retrieval.*`, `shared/retrieval/benchmark.py`, `tests/test-semantic-retrieval.py` with rows for `lib/qmd.py`, `lib/qmd.sh`/`lib/qmd.ps1`, `shared/qmd/*.mjs`, `tests/test-qmd-*.mjs`, `tests/test-qmd-setup.py`; rewrite line 43 to point at `qmd-benchmark.mjs`.
- `docs/skills.md` line 8: `installed only while local QMD search is enabled`.
- `docs/hooks.md`: add the row `| Codex and Claude | SessionStart | Warm the QMD index and search daemon in the background (only while local QMD search is enabled). |`.

- [ ] **Step 4: Rebuild and measure the prompt budget**

Run: `pwsh -NoProfile -File scripts/commands/build.ps1 -Summary` → `Build: PASS`.
Run: `pwsh -NoProfile -File scripts/commands/prompt-budget.ps1 -Summary`. If `skill_metadata_tokens` or `instruction_tokens` exceed baseline +10%, update the two baseline files with the measured values and note old → new in the commit body.

- [ ] **Step 5: Run checks**

Run: `pwsh -NoProfile -File scripts/tests/test-build-validation.ps1 -Summary` → PASS.
Run: `python scripts/tests/test-prompt-budget.py` → PASS.

- [ ] **Step 6: Commit**

```bash
git add shared/skills/research/semantic-search/SKILL.md shared/rules/general.md README.md docs/plugins.md docs/scripts.md docs/skills.md docs/hooks.md adapters/prompt-budget-baseline.json adapters/prompt-budget-baseline.tsv
git commit -m "docs(qmd): make semantic search mandatory and document QMD local search"
```

---

### Task 10: CI job and A/B benchmark integration

**Files:**
- Modify: `.gitea/workflows/ci.yml` (replace the `retrieval` job; add Node tests to the `python` job's neighbor)
- Modify: `scripts/benchmarks/ab.py:82-88,279-306,349-351,380-381`
- Create: `scripts/tests/test-qmd-integration.mjs`

**Interfaces:**
- Consumes: everything above.
- Produces: CI job `qmd` named `QMD local search integration`.

- [ ] **Step 1: Write the integration test**

```js
// scripts/tests/test-qmd-integration.mjs — real QMD, real models; run only in the qmd CI job or manually.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

const search = resolve('shared/qmd/qmd-search.mjs');

test('wrapper finds the retry logic through the daemon and stops it', { timeout: 1_800_000 }, () => {
  const home = mkdtempSync(join(tmpdir(), 'qmd-it-home-'));
  const repo = join(home, 'repo');
  mkdirSync(join(repo, 'src'), { recursive: true });
  writeFileSync(join(repo, 'src', 'upload.ts'), 'export async function sendWithRetry(send) {\n  for (let attempt = 1; attempt <= 3; attempt++) {\n    try { return await send(); } catch (e) { if (!e.transient || attempt === 3) throw e; }\n  }\n}\n');
  writeFileSync(join(repo, 'src', 'price.ts'), 'export const formatCents = (c) => (c / 100).toFixed(2);\n');
  execFileSync('git', ['init', '-q'], { cwd: repo });
  execFileSync('git', ['add', '-A'], { cwd: repo });
  const env = { ...process.env, HOME: home, USERPROFILE: home, XDG_CONFIG_HOME: join(home, '.config'), XDG_CACHE_HOME: process.env.QMD_TEST_CACHE || join(home, '.cache'), QMD_FORCE_CPU: '1' };
  execFileSync('node', ['shared/qmd/qmd-config.mjs', 'set-models'], { env });
  const results = JSON.parse(execFileSync('node', [search, '--root', repo, '--query', 'Where are failed uploads retried after temporary errors?'], { env, encoding: 'utf8', timeout: 1_700_000 }));
  assert.equal(results[0].path.replace(/\\/g, '/'), 'src/upload.ts');
  execFileSync('node', [search, '--stop'], { env });
});
```

Note: the scripts read `homedir()`, which follows `HOME` on POSIX (the CI runner is Ubuntu).

- [ ] **Step 2: Replace the CI job**

Replace the whole `retrieval:` job in `.gitea/workflows/ci.yml` with:

```yaml
  qmd:
    name: QMD local search integration
    runs-on: ubuntu-latest
    timeout-minutes: 45
    needs: [python]
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: actions/setup-node@a0853c24544627f65ddf259abe73b1d18a591444 # v22.16.0
        with:
          node-version: '24'
      - name: Install QMD
        run: npm install --global @tobilu/qmd@2.8.3
      - uses: actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0
        with:
          path: .cache/qmd-models
          key: qmd-models-${{ runner.os }}-2.8.3-qwen3
      - name: Run QMD unit tests
        run: node --test scripts/tests/test-qmd-lib.mjs scripts/tests/test-qmd-daemon.mjs scripts/tests/test-qmd-search.mjs scripts/tests/test-qmd-warm.mjs scripts/tests/test-qmd-benchmark.mjs
      - name: Run QMD integration test with real models
        env:
          QMD_TEST_CACHE: ${{ github.workspace }}/.cache/qmd-models
        run: node --test scripts/tests/test-qmd-integration.mjs
```

The `python` job already runs every `scripts/tests/test-*.py`, so `test-qmd-setup.py` runs there without changes.

- [ ] **Step 3: Update `ab.py`**

- `claude_flags`, arm `setup-no-search`: `'Bash(*semantic-retrieval*)', 'PowerShell(*semantic-retrieval*)'` → `'Bash(*qmd-search*)', 'PowerShell(*qmd-search*)'`; the appended system prompt says `The semantic-search skill and the QMD search wrapper are unavailable in this session.`
- Replace `RETRIEVAL` and `warm_index` with:

```python
QMD_SCRIPTS = Path.home() / '.my-ai-configuration/qmd'


def warm_index(work):
    """Index the fixture and start the QMD daemon before the session, as in a repository that was searched before."""
    script = QMD_SCRIPTS / 'qmd-warm.mjs'
    if script.is_file():
        subprocess.run(['node', str(script), '--root', str(work)], capture_output=True, timeout=1800)
```

- `searches` count: `'semantic-retrieval' in command` → `'qmd-search' in command`.
- `--warm-index` help text: `start the QMD daemon and index the fixture before setup-arm sessions, outside the timing`.

- [ ] **Step 4: Run checks**

Run: `python -m py_compile scripts/benchmarks/ab.py` → no output.
Run: `python scripts/benchmarks/ab.py --clients claude --tasks 01-* --repetitions 1 --dry-run` → preflight lines, `2 runs ->`, two listed runs.
Run locally once (requires installed QMD and downloaded models): `node --test scripts/tests/test-qmd-integration.mjs` → PASS.

- [ ] **Step 5: Commit**

```bash
git add .gitea/workflows/ci.yml scripts/benchmarks/ab.py scripts/tests/test-qmd-integration.mjs
git commit -m "ci(qmd): replace the Qwen retrieval job with a QMD integration job"
```

---

### Task 11: End-to-end verification on this machine

**Files:** none changed unless a check fails.

- [ ] **Step 1: Full local checks**

Run each and record the result line:

```bash
node --test scripts/tests/test-qmd-*.mjs
python scripts/tests/test-qmd-setup.py
python scripts/tests/test-install-options.py
python scripts/tests/test-managed-extensions.py
bash scripts/tests/test-install-guards.sh --summary
pwsh -NoProfile -File scripts/tests/test-install-guards.ps1 -Summary
pwsh -NoProfile -File scripts/commands/build.ps1 -Summary
pwsh -NoProfile -File scripts/commands/prompt-budget.ps1 -Summary
pwsh -NoProfile -File scripts/tests/test-build-validation.ps1 -Summary
bash scripts/commands/install.sh --summary --dry-run --client both --shell bash
```

Expected: every line PASS.

On Windows, additionally confirm the hook entry point and detached daemon start: `pwsh -NoProfile -File shared/hooks/scripts/Start-QmdWarm.ps1` returns immediately with exit code 0 inside this repository, and `node shared/qmd/qmd-benchmark.mjs --detect` lists every installed GPU.

- [ ] **Step 2: Report**

Report each result to the user. Do **not** run a real install or update on this machine: the repository's instructions forbid changing the local machine outside the repository. Tell the user the exact command to run themselves to try it: `pwsh -File scripts/commands/update.ps1` and answer `a` at the QMD question.
