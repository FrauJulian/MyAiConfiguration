// Real QMD, real models; run only in the qmd CI job or manually.
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
  assert.equal(results[0].path.replace(/\/g, '/'), 'src/upload.ts');
  execFileSync('node', [search, '--stop'], { env });
});
