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
