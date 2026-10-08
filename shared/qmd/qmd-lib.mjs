// shared/qmd/qmd-lib.mjs
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export const MODELS = {
  embed: 'hf:Qwen/Qwen3-Embedding-0.6B-GGUF/Qwen3-Embedding-0.6B-Q8_0.gguf',
  rerank: 'hf:ggml-org/Qwen3-Reranker-0.6B-Q8_0-GGUF/qwen3-reranker-0.6b-q8_0.gguf',
  generate: 'hf:tobil/qmd-query-expansion-1.7B-gguf/qmd-query-expansion-1.7B-q4_k_m.gguf',
};
export const MASK = '**/*.{md,py,cs,ts,tsx,js,jsx,mjs,go,rs,java,ps1,sh,json,yml,yaml,xml,sql}';

export function collectionName(repoPath) {
  return 'repo-' + createHash('sha256').update(resolve(repoPath), 'utf8').digest('hex').slice(0, 12);
}

export const stateDir = (home = homedir()) => join(home, '.my-ai-configuration', 'qmd');
export const setupStatePath = (home = homedir()) => join(home, '.my-ai-configuration', 'qmd.json');

export function qmdConfigPath(env = process.env, home = homedir()) {
  const dir = env.QMD_CONFIG_DIR || (env.XDG_CONFIG_HOME ? join(env.XDG_CONFIG_HOME, 'qmd') : join(home, '.config', 'qmd'));
  return join(dir, 'index.yml');
}

export function qmdDbPath(env = process.env, home = homedir()) {
  return join(env.XDG_CACHE_HOME || join(home, '.cache'), 'qmd', 'index.sqlite');
}

export function deviceEnv(device, env = process.env) {
  const result = { ...env };
  if (device === 'cpu') {
    result.QMD_FORCE_CPU = '1';
    delete result.QMD_LLAMA_GPU;
  } else {
    result.QMD_LLAMA_GPU = 'auto';
    delete result.QMD_FORCE_CPU;
  }
  return result;
}

export function idleMinutes(env = process.env) {
  const value = Number(env.QMD_IDLE_MINUTES);
  return Number.isFinite(value) && value > 0 ? value : 30;
}

export function readJson(path, fallback) {
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch {
    return fallback;
  }
}

// The state directory lives in the user profile; mode 0600 restricts the token on POSIX.
export function writePrivateJson(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  const temporary = `${path}.${process.pid}.tmp`;
  writeFileSync(temporary, JSON.stringify(value, null, 2) + '\n', { mode: 0o600 });
  renameSync(temporary, path);
}

let cachedPackageDir;

export function qmdPackageDir() {
  if (process.env.QMD_PACKAGE_DIR) return process.env.QMD_PACKAGE_DIR;
  if (!cachedPackageDir) {
    const root = execFileSync('npm', ['root', '--global'], { encoding: 'utf8', shell: process.platform === 'win32', windowsHide: true }).trim();
    cachedPackageDir = join(root, '@tobilu', 'qmd');
  }
  return cachedPackageDir;
}

export function importQmd(subpath = join('dist', 'index.js')) {
  return import(pathToFileURL(join(qmdPackageDir(), subpath)).href);
}

// Runs the QMD CLI through node without a shell, so free-text arguments are never re-parsed.
export function runQmdCli(args, options = {}) {
  return execFileSync(process.execPath, [join(qmdPackageDir(), 'dist', 'cli', 'qmd.js'), ...args], { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024, ...options });
}
