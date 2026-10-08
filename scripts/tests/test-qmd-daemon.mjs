// scripts/tests/test-qmd-daemon.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync, utimesSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { createServer, gitFingerprint, keepModelsLoaded } from '../../shared/qmd/qmd-daemon.mjs';
import { collectionName } from '../../shared/qmd/qmd-lib.mjs';

const defaultHits = () => [{ displayPath: `${collectionName('/r')}/src/a.ts`, body: 'x\nretry here', bestChunkPos: 2, bestChunk: 'retry here', score: 0.91 }];

function fakeStore(updateGate, hits = defaultHits) {
  const calls = [];
  return {
    calls,
    listCollections: async () => [{ name: 'notes', includeByDefault: true }, ...calls.filter((c) => c[0] === 'add').map((c) => ({ name: c[1] }))],
    getDefaultCollectionNames: async () => ['notes', 'repo-aaaaaaaaaaaa', 'repo-notes'],
    addCollection: async (name, opts) => calls.push(['add', name, opts]),
    update: async (opts) => { calls.push(['update', opts]); await updateGate; return { indexed: 1 }; },
    embed: async (opts) => { calls.push(['embed', opts]); return { chunksEmbedded: 1 }; },
    search: async (opts) => { calls.push(['search', opts]); return hits(); },
  };
}

async function start(t, overrides = {}, { updateGate, hits } = {}) {
  const store = fakeStore(updateGate, hits);
  let clock = 0;
  const idle = [];
  const daemon = createServer({
    store, token: 't0k', idleMs: 1000, now: () => clock, onIdle: () => idle.push(clock),
    extractSnippet: () => ({ line: 2, snippet: 'retry here' }),
    git: () => 'fingerprint-1', excludeCollection: async () => {}, recordCollection: () => {}, ...overrides,
  });
  await new Promise((done) => daemon.server.listen(0, '127.0.0.1', done));
  t.after(() => { daemon.server.closeAllConnections(); daemon.server.close(); });
  const port = daemon.server.address().port;
  const call = (path, body, token = 't0k') => fetch(`http://127.0.0.1:${port}${path}`, {
    method: body === undefined ? 'GET' : 'POST', headers: { connection: 'close', 'x-qmd-token': token, 'content-type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body) });
  const raw = (path, body) => fetch(`http://127.0.0.1:${port}${path}`, { method: 'POST', headers: { connection: 'close', 'x-qmd-token': 't0k' }, body });
  return { daemon, store, call, raw, setClock: (v) => { clock = v; }, idle };
}

const wait = (ms) => new Promise((done) => setTimeout(done, ms));
const gateOf = () => { let release; const gate = new Promise((done) => { release = done; }); return { gate, release }; };

test('rejects requests without the token', async (t) => {
  const s = await start(t);
  assert.equal((await s.call('/health', undefined, 'wrong')).status, 403);
});

test('health identifies the service', async (t) => {
  const s = await start(t);
  assert.equal((await (await s.call('/health')).json()).service, 'ai-config-qmd');
});

test('search adds the repo collection once, refreshes on change, and filters other repos', async (t) => {
  const s = await start(t);
  const body = await (await s.call('/search', { repo: '/r', query: 'where are retries', limit: 3 })).json();
  assert.deepEqual(body.results, [{ path: 'src/a.ts', line: 2, score: 0.91, snippet: 'retry here' }]);
  const search = s.store.calls.find((c) => c[0] === 'search')[1];
  assert.equal(search.query, 'where are retries');
  assert.ok(search.collections.includes('notes'));
  assert.ok(!search.collections.includes('repo-aaaaaaaaaaaa'));
  assert.ok(search.collections.includes('repo-notes'), 'only hash-named repo collections are filtered');
  assert.equal(search.collections.filter((n) => /^repo-[0-9a-f]{12}$/.test(n)).length, 1);
  assert.equal(s.store.calls.filter((c) => c[0] === 'add').length, 1);
  assert.equal(s.store.calls.find((c) => c[0] === 'add')[2].path, resolve('/r'));
  await s.call('/search', { repo: '/r', query: 'again', limit: 3 });
  assert.equal(s.store.calls.filter((c) => c[0] === 'update').length, 1, 'unchanged fingerprint skips update');
});

test('rejects a missing query', async (t) => {
  const s = await start(t);
  assert.equal((await s.call('/search', { repo: '/r' })).status, 400);
});

test('idle check calls onIdle only after the idle window', async (t) => {
  const s = await start(t);
  s.setClock(500); s.daemon.checkIdle(); assert.deepEqual(s.idle, []);
  s.setClock(1500); s.daemon.checkIdle(); assert.deepEqual(s.idle, [1500]);
});

test('a changed fingerprint triggers update and embed again', async (t) => {
  let fingerprint = 'one';
  const s = await start(t, { git: () => fingerprint });
  await s.call('/search', { repo: '/r', query: 'q' });
  fingerprint = 'two';
  await s.call('/search', { repo: '/r', query: 'q' });
  assert.equal(s.store.calls.filter((c) => c[0] === 'update').length, 2);
  assert.equal(s.store.calls.filter((c) => c[0] === 'embed').length, 2);
});

test('fingerprint changes when an already dirty file is edited again', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'qmd-fp-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', ['-C', dir, '-c', 'user.name=t', '-c', 'user.email=t@t', ...args], { stdio: 'ignore' });
  git('init', '-q');
  writeFileSync(join(dir, 'a.ts'), 'one');
  git('add', '.');
  git('commit', '-qm', 'init');
  writeFileSync(join(dir, 'a.ts'), 'two');
  const first = gitFingerprint(dir);
  writeFileSync(join(dir, 'a.ts'), 'three!');
  utimesSync(join(dir, 'a.ts'), new Date(), new Date(Date.now() + 5000));
  assert.notEqual(gitFingerprint(dir), first);
});

test('a failing exclude does not stop the search and is retried', async (t) => {
  let attempts = 0;
  const recorded = [];
  const s = await start(t, {
    excludeCollection: async () => { attempts++; if (attempts === 1) throw new Error('boom'); },
    recordCollection: (name) => recorded.push(name),
  });
  const first = await s.call('/search', { repo: '/r', query: 'q' });
  assert.equal(first.status, 200);
  assert.equal((await first.json()).results.length, 1);
  assert.deepEqual(recorded, []);
  await s.call('/search', { repo: '/r', query: 'q' });
  assert.equal(attempts, 2);
  assert.equal(recorded.length, 1);
});

test('concurrent searches share one refresh', async (t) => {
  const { gate, release } = gateOf();
  const s = await start(t, {}, { updateGate: gate });
  const both = Promise.all([s.call('/search', { repo: '/r', query: 'a' }), s.call('/search', { repo: '/r', query: 'b' })]);
  await wait(100);
  release();
  await both;
  assert.equal(s.store.calls.filter((c) => c[0] === 'update').length, 1);
});

test('idle check waits for in-flight requests', async (t) => {
  const { gate, release } = gateOf();
  const s = await start(t, {}, { updateGate: gate });
  const pending = s.call('/search', { repo: '/r', query: 'a' });
  await wait(100);
  s.setClock(5000); s.daemon.checkIdle(); assert.deepEqual(s.idle, []);
  release();
  await pending;
});

test('malformed or non-object bodies give 400 and limit is clamped', async (t) => {
  const s = await start(t);
  assert.equal((await s.raw('/search', '{nope')).status, 400);
  assert.equal((await s.raw('/search', '[1]')).status, 400);
  assert.equal((await s.raw('/search', 'null')).status, 400);
  await s.call('/search', { repo: '/r', query: 'q', limit: 9999 });
  await s.call('/search', { repo: '/r', query: 'q', limit: 'x' });
  const limits = s.store.calls.filter((c) => c[0] === 'search').map((c) => c[1].limit);
  assert.deepEqual(limits, [20, 5]);
});

test('non-repo hits become qmd:// URIs', async (t) => {
  const s = await start(t, {}, { hits: () => [{ displayPath: 'notes/todo.md', body: 'x', bestChunkPos: 0, bestChunk: 'x', score: 0.5 }] });
  const body = await (await s.call('/search', { repo: '/r', query: 'q' })).json();
  assert.equal(body.results[0].path, 'qmd://notes/todo.md');
});

test('refresh, stop, 404 and 403 on POST routes', async (t) => {
  const s = await start(t);
  assert.deepEqual(await (await s.call('/refresh', { repo: '/r' })).json(), { collection: collectionName('/r'), updated: true });
  assert.equal((await s.call('/nothing', { repo: '/r' })).status, 404);
  assert.equal((await s.call('/search', { repo: '/r', query: 'q' }, 'wrong')).status, 403);
  assert.deepEqual(await (await s.call('/stop', {})).json(), { stopping: true });
  assert.equal(s.idle.length, 1);
});

test('keepModelsLoaded disables QMD unloading models after 5 idle minutes', () => {
  const llm = { inactivityTimeoutMs: 5 * 60 * 1000, disposeModelsOnInactivity: true };
  keepModelsLoaded({ internal: { llm } });
  assert.deepEqual(llm, { inactivityTimeoutMs: 0, disposeModelsOnInactivity: false });
});
