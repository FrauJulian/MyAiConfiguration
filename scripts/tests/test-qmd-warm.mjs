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

test('an empty or non-numeric lock counts as stale', async () => {
  for (const content of ['', 'garbage']) {
    const lock = join(mkdtempSync(join(tmpdir(), 'qmd-warm-')), 'repo.lock');
    writeFileSync(lock, content);
    let runs = 0;
    await withLock(lock, async () => { runs += 1; });
    assert.equal(runs, 1);
  }
});

test('a run never removes a lock that another run took over', async () => {
  const lock = join(mkdtempSync(join(tmpdir(), 'qmd-warm-')), 'repo.lock');
  await withLock(lock, async () => { writeFileSync(lock, 'other-run'); });
  assert.equal(existsSync(lock), true);
});
