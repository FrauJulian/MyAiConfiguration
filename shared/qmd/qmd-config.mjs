// shared/qmd/qmd-config.mjs — edits only the models: block of QMD's index.yml.
import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { MODELS, qmdConfigPath, qmdPackageDir } from './qmd-lib.mjs';

export function setModels(text, YAML) {
  const document = YAML.parseDocument(text || '');
  if (document.errors.length) throw new Error(`index.yml cannot be parsed: ${document.errors[0].message}`);
  if (document.contents === null) document.contents = document.createNode({});
  document.set('models', document.createNode({ ...MODELS }));
  return document.toString();
}

export function previousModels(text, YAML) {
  const document = YAML.parseDocument(text || '');
  if (document.errors.length) throw new Error(`index.yml cannot be parsed: ${document.errors[0].message}`);
  return document.contents === null ? null : document.toJS().models ?? null;
}

export function restoreModels(text, YAML, mapping) {
  const document = YAML.parseDocument(text || '');
  if (document.errors.length) throw new Error(`index.yml cannot be parsed: ${document.errors[0].message}`);
  if (document.contents === null) document.contents = document.createNode({});
  document.set('models', document.createNode(mapping));
  return document.toString();
}

export function unsetModels(text, YAML) {
  const document = YAML.parseDocument(text || '');
  if (document.errors.length) throw new Error(`index.yml cannot be parsed: ${document.errors[0].message}`);
  if (document.contents !== null) document.delete('models');
  return document.contents === null || document.contents.items?.length === 0 ? '' : document.toString();
}

async function main(action, argument) {
  if (!['set-models', 'unset-models', 'restore-models'].includes(action)) throw new Error('usage: qmd-config.mjs set-models|unset-models|restore-models <json>');
  const YAML = await import(pathToFileURL(join(qmdPackageDir(), 'node_modules', 'yaml', 'dist', 'index.js')).href);
  const path = qmdConfigPath();
  const current = existsSync(path) ? readFileSync(path, 'utf8') : '';
  let next;
  if (action === 'set-models') {
    const previous = previousModels(current, YAML);
    // A block equal to ours is a leftover of an interrupted run, not the user's own.
    console.log(JSON.stringify({ previous: JSON.stringify(previous) === JSON.stringify(MODELS) ? null : previous }));
    next = setModels(current, YAML);
  } else if (action === 'restore-models') {
    const mapping = JSON.parse(argument ?? '');
    if (mapping === undefined) throw new Error('restore-models needs a JSON value');
    next = restoreModels(current, YAML, mapping);
  } else next = unsetModels(current, YAML);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, next);
}

if (import.meta.url === pathToFileURL(process.argv[1] || '').href) {
  main(process.argv[2], process.argv[3]).catch((error) => { console.error(`qmd-config: ${error.message}`); process.exit(1); });
}
