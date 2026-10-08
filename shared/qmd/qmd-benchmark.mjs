// shared/qmd/qmd-benchmark.mjs — measures warm QMD search latency and embedding throughput on one device.
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { availableParallelism, tmpdir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';
import { MODELS, importQmd, qmdPackageDir } from './qmd-lib.mjs';

export function passes({ querySeconds, chunksPerSecond }, env = process.env) {
  const maxQuery = Number(env.QMD_BENCHMARK_MAX_QUERY_SECONDS) || 5;
  const minChunks = Number(env.QMD_BENCHMARK_MIN_CHUNKS_PER_SECOND) || 20;
  return querySeconds <= maxQuery && chunksPerSecond >= minChunks;
}

const TOPICS = ['invoice rounding', 'upload retries', 'trial expiry', 'cache invalidation', 'session tokens'];

export function fixtureDocuments(count) {
  return Array.from({ length: count }, (_, index) => {
    const topic = TOPICS[index % TOPICS.length];
    const sections = Array.from({ length: 6 }, (__, section) =>
      `## ${topic} part ${section}\n\n` + (`This section ${index}-${section} explains how ${topic} behaves when the service handles request ${index * 7 + section}. ` +
      `It lists the edge cases, the configuration keys, and the error messages that operators see during incidents.\n`).repeat(2));
    return { name: `doc-${String(index).padStart(3, '0')}.md`, text: `# ${topic} ${index}\n\n${sections.join('\n')}` };
  });
}

export function embedThroughput({ chunksEmbedded, durationMs, errors }) {
  return { chunksPerSecond: chunksEmbedded / Math.max(durationMs / 1000, 0.001), ok: !errors && chunksEmbedded > 0 };
}

export function describeDevices({ gpu, devices, threads }) {
  const gpus = gpu ? `${String(gpu).toUpperCase()}: ${devices.join(', ') || 'unnamed device'}` : 'no GPU';
  return `${gpus}; CPU threads: ${threads}`;
}

// llama.cpp's automatic backend uses every GPU of the chosen backend; nothing here narrows the device set.
async function detect() {
  const { getLlama } = await import(pathToFileURL(join(qmdPackageDir(), 'node_modules', 'node-llama-cpp', 'dist', 'index.js')).href);
  const llama = await getLlama({ gpu: 'auto' });
  try {
    const gpu = llama.gpu;
    const devices = gpu ? await llama.getGpuDeviceNames() : [];
    return { gpu, devices, threads: availableParallelism() };
  } finally {
    await llama.dispose();
  }
}

async function measure(device) {
  for (const [key, value] of Object.entries({ QMD_EMBED_MODEL: MODELS.embed, QMD_RERANK_MODEL: MODELS.rerank, QMD_GENERATE_MODEL: MODELS.generate })) {
    process.env[key] = value;
  }
  const work = mkdtempSync(join(tmpdir(), 'ai-config-qmd-bench-'));
  try {
    const docs = join(work, 'docs');
    mkdirSync(docs);
    for (const doc of fixtureDocuments(100)) writeFileSync(join(docs, doc.name), doc.text);
    const { createStore } = await importQmd();
    const store = await createStore({ dbPath: join(work, 'index.sqlite'), config: { collections: { bench: { path: docs, pattern: '**/*.md' } } } });
    try {
      await store.update();
      await store.embed({ collection: 'bench' }); // warm-up: loads (and on a first run downloads) the model
      const embedded = await store.embed({ collection: 'bench', force: true });
      const { chunksPerSecond, ok } = embedThroughput(embedded);
      const question = 'Which part explains how upload retries behave during incidents?';
      await store.search({ query: question, collections: ['bench'], limit: 5 });
      const times = [];
      for (let run = 0; run < 3; run += 1) {
        const started = performance.now();
        await store.search({ query: `${question} (${run})`, collections: ['bench'], limit: 5, candidateLimit: 40 });
        times.push((performance.now() - started) / 1000);
      }
      const querySeconds = times.sort((a, b) => a - b)[1];
      const result = { device, querySeconds: Number(querySeconds.toFixed(3)), chunksPerSecond: Number(chunksPerSecond.toFixed(1)), embedErrors: embedded.errors };
      return { ...result, passed: ok && passes(result) };
    } finally {
      await store.close();
    }
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
}

async function main() {
  const { values } = parseArgs({ options: { detect: { type: 'boolean' }, device: { type: 'string' } } });
  if (values.detect) return console.log(JSON.stringify(await detect()));
  if (!['gpu', 'cpu'].includes(values.device)) throw new Error('--device gpu|cpu or --detect is required');
  console.log(JSON.stringify(await measure(values.device)));
}

if (import.meta.url === pathToFileURL(process.argv[1] || '').href) {
  main().catch((error) => { console.error(`qmd-benchmark: ${error.message}`); process.exit(1); });
}
