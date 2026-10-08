// Loads QMD's yaml dependency for tests, including hoisted installations.
import { importQmdDependency } from '../../../shared/qmd/qmd-lib.mjs';
const YAML = await importQmdDependency('yaml');
export const parseDocument = YAML.parseDocument;
export default YAML;
