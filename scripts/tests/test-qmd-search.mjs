import { test } from 'node:test';
import assert from 'node:assert/strict';
import { runSearch, toCliResults } from '../../shared/qmd/qmd-search.mjs';
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
    daemon: async () => { calls += 1; if (calls === 1) throw new Error('ECONNREFUSED'); return { results: hit }; },
    startDaemon: async () => { started += 1; }, cli: async () => assert.fail('must not fall back') });
  assert.deepEqual(results, hit);
  assert.equal(started, 1);
});

test('falls back to the CLI when the daemon cannot start', async () => {
  const results = await runSearch({ root: '/r', query: 'q', topK: 2,
    daemon: async () => { throw new Error('stale'); }, startDaemon: async () => { throw new Error('spawn failed'); },
    cli: async (args) => { assert.ok(args.includes('--json')); return [{ file: `qmd://${collectionName('/r')}/src/b.ts`, line: 7, score: 0.5, snippet: 'b' }]; } });
  assert.deepEqual(results, [{ path: 'src/b.ts', line: 7, score: 0.5, snippet: 'b' }]);
});

test('CLI results keep foreign collections as qmd URIs', () => {
  assert.deepEqual(toCliResults([{ file: 'qmd://notes/x.md', line: 1, score: 0.4, snippet: 'n' }], 'repo-x'),
    [{ path: 'qmd://notes/x.md', line: 1, score: 0.4, snippet: 'n' }]);
});
