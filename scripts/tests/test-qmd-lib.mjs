import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import * as YAML from './fixtures/yaml-shim.mjs';
import { collectionName, deviceEnv, idleMinutes, qmdConfigPath, writePrivateJson, writeTextAtomic, readJson, runQmdCli, MODELS } from '../../shared/qmd/qmd-lib.mjs';
import { setModels, unsetModels, previousModels, restoreModels } from '../../shared/qmd/qmd-config.mjs';

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

test('runQmdCli runs the CLI entry of QMD_PACKAGE_DIR without a shell', () => {
  const dir = mkdtempSync(join(tmpdir(), 'qmd-pkg-'));
  mkdirSync(join(dir, 'dist', 'cli'), { recursive: true });
  writeFileSync(join(dir, 'dist', 'cli', 'qmd.js'), 'console.log(JSON.stringify(process.argv.slice(2)));\n');
  const previous = process.env.QMD_PACKAGE_DIR;
  process.env.QMD_PACKAGE_DIR = dir;
  try {
    assert.deepEqual(JSON.parse(runQmdCli(['search', 'a "b" & c'])), ['search', 'a "b" & c']);
  } finally {
    if (previous === undefined) delete process.env.QMD_PACKAGE_DIR; else process.env.QMD_PACKAGE_DIR = previous;
  }
});

test('previousModels captures a user models block, null when absent', () => {
  assert.deepEqual(previousModels('models:\n  embed: mine\ncollections: {}\n', YAML), { embed: 'mine' });
  assert.equal(previousModels('models: custom\n', YAML), 'custom');
  assert.deepEqual(previousModels('models: [a, b]\n', YAML), ['a', 'b']);
  assert.equal(previousModels('collections: {}\n', YAML), null);
  assert.equal(previousModels('', YAML), null);
});

test('restoreModels writes the previous block back and keeps comments and other keys', () => {
  const original = '# keep\ncollections:\n  a: {}\nmodels:\n  embed: mine\n';
  const replaced = setModels(original, YAML);
  const restored = restoreModels(replaced, YAML, { embed: 'mine' });
  assert.match(restored, /# keep/);
  assert.match(restored, /embed: mine/);
  assert.match(restored, /collections:/);
  assert.doesNotMatch(restored, /Qwen/);
});

test('writeTextAtomic replaces the file through a temp file in the same directory', () => {
  const dir = join(mkdtempSync(join(tmpdir(), 'qmd-lib-')), 'cfg');
  const file = join(dir, 'index.yml');
  writeTextAtomic(file, 'a: 1\n');
  writeTextAtomic(file, 'b: 2\n');
  assert.equal(readFileSync(file, 'utf8'), 'b: 2\n');
  assert.deepEqual(readdirSync(dir), ['index.yml']);
});
