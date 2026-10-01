import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mergeConfig } from '../src/config.ts';

test('nested objects merge deeply', () => {
  const base = { server: { host: 'a', port: 1, tls: { on: true } }, tags: ['x'] };
  const override = { server: { port: 2, tls: { cert: 'c' } }, tags: ['y', 'z'] };
  assert.deepEqual(mergeConfig(base, override), { server: { host: 'a', port: 2, tls: { on: true, cert: 'c' } }, tags: ['y', 'z'] });
});

test('inputs are not mutated', () => {
  const base = { a: { b: 1 } };
  const override = { a: { c: 2 } };
  mergeConfig(base, override);
  assert.deepEqual(base, { a: { b: 1 } });
  assert.deepEqual(override, { a: { c: 2 } });
});
