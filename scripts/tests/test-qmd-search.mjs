import { test } from 'node:test';
import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { runSearch, startDaemon, toCliResults } from '../../shared/qmd/qmd-search.mjs';
import { collectionName } from '../../shared/qmd/qmd-lib.mjs';

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
    daemon: async () => { calls += 1; if (calls === 1) throw Object.assign(new Error('ECONNREFUSED'), { notRunning: true }); return { results: hit }; },
    startDaemon: async () => { started += 1; }, cli: async () => assert.fail('must not fall back') });
  assert.deepEqual(results, hit);
  assert.equal(started, 1);
});

test('falls back to the CLI when the daemon cannot start', async () => {
  const results = await runSearch({ root: '/r', query: 'q', topK: 2,
    daemon: async () => { throw Object.assign(new Error('stale'), { notRunning: true }); }, startDaemon: async () => { throw new Error('spawn failed'); },
    cli: async (args) => { assert.ok(args.includes('--json')); return [{ file: `qmd://${collectionName('/r')}/src/b.ts`, line: 7, score: 0.5, snippet: 'b' }]; } });
  assert.deepEqual(results, [{ path: 'src/b.ts', line: 7, score: 0.5, snippet: 'b' }]);
});

test('CLI results keep foreign collections as qmd URIs', () => {
  assert.deepEqual(toCliResults([{ file: 'qmd://notes/x.md', line: 1, score: 0.4, snippet: 'n' }], 'repo-x'),
    [{ path: 'qmd://notes/x.md', line: 1, score: 0.4, snippet: 'n' }]);
});

const cliHit = (root) => async () => [{ file: `qmd://${collectionName(root)}/src/b.ts`, line: 7, score: 0.5, snippet: 'b' }];
const cliExpected = [{ path: 'src/b.ts', line: 7, score: 0.5, snippet: 'b' }];

test('a live daemon that answers with an error does not trigger a second daemon', async () => {
  const results = await runSearch({ root: '/r', query: 'q', topK: 2,
    daemon: async () => { throw new Error('daemon answered 500'); },
    startDaemon: async () => assert.fail('must not start'), cli: cliHit('/r') });
  assert.deepEqual(results, cliExpected);
});

test('a daemon reply without results falls back to the CLI', async () => {
  const results = await runSearch({ root: '/r', query: 'q', topK: 2,
    daemon: async () => ({}), startDaemon: async () => assert.fail('must not start'), cli: cliHit('/r') });
  assert.deepEqual(results, cliExpected);
});

test('a daemon failure after a successful start falls back to the CLI', async () => {
  let calls = 0;
  const results = await runSearch({ root: '/r', query: 'q', topK: 2,
    daemon: async () => { calls += 1; throw calls === 1 ? Object.assign(new Error('down'), { notRunning: true }) : new Error('daemon answered 500'); },
    startDaemon: async () => {}, cli: cliHit('/r') });
  assert.deepEqual(results, cliExpected);
  assert.equal(calls, 2);
});

test('startDaemon rejects quickly when the child exits immediately', async () => {
  const started = Date.now();
  await assert.rejects(startDaemon({ spawnChild: () => {
    const child = new EventEmitter(); child.unref = () => {}; child.pid = 1;
    setImmediate(() => child.emit('exit', 1));
    return child;
  } }), /exited with code 1/);
  assert.ok(Date.now() - started < 5000);
});

test('startDaemon rejects when the child cannot be spawned', async () => {
  await assert.rejects(startDaemon({ spawnChild: () => {
    const child = new EventEmitter(); child.unref = () => {}; child.pid = 1;
    setImmediate(() => child.emit('error', new Error('spawn failed')));
    return child;
  } }), /spawn failed/);
});
