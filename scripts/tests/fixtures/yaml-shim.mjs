// Loads QMD's bundled yaml package for tests.
import { qmdPackageDir } from '../../../shared/qmd/qmd-lib.mjs';
import { pathToFileURL } from 'node:url';
import { join } from 'node:path';
const YAML = await import(pathToFileURL(join(qmdPackageDir(), 'node_modules', 'yaml', 'dist', 'index.js')).href);
export const parseDocument = YAML.parseDocument;
export default YAML;
