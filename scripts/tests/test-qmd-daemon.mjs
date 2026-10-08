// scripts/tests/test-qmd-daemon.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from '../../shared/qmd/qmd-daemon.mjs';
import { collectionName } from '../../shared/qmd/qmd-lib.mjs';

function fakeStore() {
  const calls = [];
  return {
    calls,
    listCollections: async () => [{ name: 'notes', includeByDefault: true }],
    getDefaultCollectionNames: async () => ['notes', 'repo-aaaaaaaaaaaa'],
    addCollection: async (name, opts) => calls.push(['add', name, opts]),
    update: async (opts) => { calls.push(['update', opts]); return { indexed: 1 }; },
    embed: async (opts) => { calls.push(['embed', opts]); return { chunksEmbedded: 1 }; },
    search: async (opts) => { calls.push(['search', opts]); return [{ displayPath: `${collectionName('/r')}/src/a.ts`, body: 'x\nretry here', bestChunkPos: 2, bestChunk: 'retry here', score: 0.91, file: 'qmd://repo/src/a.ts' }]; },
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
