// shared/qmd/qmd-config.mjs — edits only the models: block and setup-owned collection ignore lists in QMD's index.yml.
import { existsSync, readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { MODELS, importQmdDependency, qmdConfigPath, writeTextAtomic } from './qmd-lib.mjs';

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

// Returns the new text, or null when index.yml has no such collection (QMD's write-through always creates it).
export function setCollectionIgnore(text, YAML, name, ignore) {
  const document = YAML.parseDocument(text || '');
  if (document.errors.length) throw new Error(`index.yml cannot be parsed: ${document.errors[0].message}`);
  if (!document.hasIn(['collections', name])) return null;
  if (ignore.length) document.setIn(['collections', name, 'ignore'], document.createNode(ignore));
  else document.deleteIn(['collections', name, 'ignore']);
  return document.toString();
}

async function main(action, argument) {
  if (!['set-models', 'unset-models', 'restore-models'].includes(action)) throw new Error('usage: qmd-config.mjs set-models|unset-models|restore-models <json>');
  const YAML = await importQmdDependency('yaml');
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
  writeTextAtomic(path, next);
}

if (import.meta.url === pathToFileURL(process.argv[1] || '').href) {
  main(process.argv[2], process.argv[3]).catch((error) => { console.error(`qmd-config: ${error.message}`); process.exit(1); });
}
