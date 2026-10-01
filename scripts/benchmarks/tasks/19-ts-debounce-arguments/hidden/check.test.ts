import { test, mock } from 'node:test';
import assert from 'node:assert/strict';
import { debounce } from '../src/debounce.ts';

test('trailing call uses the latest arguments', () => {
  mock.timers.enable({ apis: ['setTimeout'] });
  const calls: number[][] = [];
  const run = debounce((value: number) => calls.push([value]), 50);
  run(1); run(2); run(3);
  mock.timers.tick(49);
  assert.deepEqual(calls, []);
  mock.timers.tick(1);
  assert.deepEqual(calls, [[3]]);
  run(4);
  mock.timers.tick(50);
  assert.deepEqual(calls, [[3], [4]]);
  mock.timers.reset();
});
