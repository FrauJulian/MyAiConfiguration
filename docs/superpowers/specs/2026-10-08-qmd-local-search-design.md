# QMD local search design

Date: 2026-10-08
Status: approved in conversation, pending written-spec review

## Goal

Replace the Python semantic retrieval stack with QMD as the only local search engine, used by Claude Code and Codex alike.

| Role | Model | QMD URI |
|---|---|---|
| Embedding | Qwen3-Embedding-0.6B | `hf:Qwen/Qwen3-Embedding-0.6B-GGUF/Qwen3-Embedding-0.6B-Q8_0.gguf` |
| Reranking | Qwen3-Reranker-0.6B | `hf:ggml-org/Qwen3-Reranker-0.6B-Q8_0-GGUF/qwen3-reranker-0.6b-q8_0.gguf` |
| Query expansion | QMD Query Expansion 1.7B | `hf:tobil/qmd-query-expansion-1.7B-gguf/qmd-query-expansion-1.7B-q4_k_m.gguf` |

Success criteria:

- No Python model code, virtual environment, or Python model dependency remains.
- QMD is no longer an extension in the plugin selector; the local-models question alone controls it.
- When enabled, agents use the search skill for every question whose identifiers are unknown, and the search answers in seconds because the index is warm and the models are loaded.
- When disabled or unsuitable, no skill, hook, instruction line, QMD package, or model installed by the setup remains.

Motivation from the 2026-10-08 Claude A/B benchmark: the Python search was never used in the three concept-search tasks, while the setup's fixed context made every run about 2.5 times more expensive in input tokens. A permanent MCP server would add to that cost, so the integration is a skill over a CLI wrapper.

## Decisions

1. Search scope: primarily the current Git repository; additionally user-registered QMD collections (`includeByDefault: true`), ranked together in one query.
2. Index location: one global QMD index (`~/.cache/qmd`). Each repository is a collection named `repo-<short hash of the absolute repository path>` with `includeByDefault: false`. No files are written into repositories.
3. Agent access: an own `semantic-search` skill for both clients that calls a Node wrapper. QMD's `qmd@qmd` plugin and MCP tools are not used.
4. Warm-up: a SessionStart hook indexes in the background and starts an own search daemon built on the QMD SDK so all three models stay loaded. QMD's HTTP daemon (`qmd mcp --http`) is not used: its `POST /query` accepts only pre-typed `lex`/`vec`/`hyde` searches and never runs query expansion.
5. Daemon lifetime: the daemon exits by itself after 30 idle minutes (`QMD_IDLE_MINUTES`).
6. Auto mode: benchmark GPU first, then CPU; both thresholds must pass; if no device passes, remove what the setup installed and continue as No.

## Components

### Removed

- `shared/retrieval/` (`server.py`, `benchmark.py`, `requirements.txt`).
- `scripts/lib/semantic-retrieval.py`, `.sh`, `.ps1`.
- `scripts/tests/test-retrieval-server.py`, `scripts/tests/test-semantic-retrieval.py`.
- The `retrieval` job in `.gitea/workflows/ci.yml`.
- The `QMD` row in `adapters/plugins.tsv` and QMD-specific ownership in `scripts/lib/managed-extensions.py`, `scripts/lib/plugins.sh`, and `scripts/lib/plugins.ps1`.
- Qwen/Python references in `README.md`, `docs/plugins.md`, `docs/scripts.md`, and other affected documentation.

### Added under `shared/qmd/`

- `qmd-daemon.mjs`: long-lived search process using the QMD SDK (`createStore({ dbPath, configPath })`, `store.search({ query, collections })` with expansion and reranking, `store.update()`, `store.embed()`). Listens on `127.0.0.1` only, on a port chosen at start; writes `{port, token, pid}` to `~/.my-ai-configuration/qmd/daemon.json` readable only by the user; rejects requests without the token header. Exits after `QMD_IDLE_MINUTES` (default 30) without a request. A second start while one is healthy is a no-op.
- `qmd-search.mjs`: ensures the repository collection, refreshes it incrementally, sends the search to the daemon, starts the daemon if it is not running, and falls back to `qmd query --json` when the daemon cannot be used. Collections searched: the repository collection plus every collection with `includeByDefault: true`. Output: JSON list of `{path, line, score, snippet}` with repository-relative paths, best first. 
- `qmd-warm.mjs`: started detached by the SessionStart hook. Starts the daemon with the stored device if it is not running and asks it to refresh and embed the repository collection. A per-repository lock file prevents parallel indexing from concurrent sessions.
- `qmd-benchmark.mjs`: the Auto benchmark (see below).
- Thin `.sh` and `.ps1` entry points for every script, as the repository requires.

### Changed

- `shared/skills/research/semantic-search/SKILL.md`: rewritten for QMD; name kept so references and the A/B benchmark stay stable.
- `scripts/lib/qmd.sh`, `scripts/lib/qmd.ps1`: install, update, benchmark, and removal, called from `install` and `update`.
- Hooks: SessionStart entries for Claude and Codex are generated only when local models are enabled.
- `shared/rules/general.md` (and the generated global instructions): the semantic-search line becomes mandatory and is generated only when the skill is installed.
- `scripts/benchmarks/ab.py`: `setup-no-search` blocks the skill and wrapper instead of the Python CLI; `--warm-index` runs `qmd-warm.mjs`.

### Repository collection

- Name: `repo-<first 12 hex characters of SHA-256 of the absolute repository path>`.
- Mask: `**/*.{md,py,cs,ts,tsx,js,jsx,mjs,go,rs,java,ps1,sh,json,yml,yaml,xml,sql}`.
- Chunking: `--chunk-strategy auto` (AST chunking where QMD supports it; regex chunking elsewhere, including C#).
- QMD's built-in exclusions apply (`node_modules`, `.git`, `.cache`, `vendor`, `dist`, `build`).

### Configuration and state

- `~/.config/qmd/index.yml` (or `QMD_CONFIG_DIR`): the setup writes only the `models:` block; other keys and collections are preserved. An unparsable file aborts without writing. The daemon also writes the `ignore` list (the repository's git-ignored paths) of its own `repo-*` collections, because QMD re-syncs SQLite from this file and its `addCollection` write-through drops `ignore`.
- `~/.my-ai-configuration/qmd.json`: `{version, device: "gpu" | "cpu", owned_package: bool, owned_models: [...]}`.
- Device mapping when starting QMD: `gpu` sets `QMD_LLAMA_GPU=auto` (llama.cpp uses all detected GPUs); `cpu` sets `QMD_FORCE_CPU=1`.

## Install and update flow

Question, identical in Bash and PowerShell:

`Enable local QMD search models (Qwen3 embedding, Qwen3 reranker, QMD query expansion)? [y/N/a]`

- The default is the stored selection. The selection key `semantic_retrieval` and the `-SemanticRetrieval` / `--semantic-retrieval` parameters keep their names for compatibility.
- An update that keeps the stored selection does not rerun the benchmark; the benchmark runs only when `a` is chosen explicitly.

Prerequisites: Node.js 22 or newer and `npm`. Missing with Yes: abort with a clear message before any change. Missing with Auto: treat as unsuitable (No) and report the reason.

Yes:

1. `npm install -g @tobilu/qmd@<pinned version>`; record ownership only if QMD was not already installed.
2. Write the `models:` block into `index.yml`.
3. `qmd pull`.
4. Device: `gpu` when QMD's device probe (`qmd doctor`) reports a usable GPU, otherwise `cpu`. No benchmark.
5. Install skill, hook, scripts, and the mandatory instruction line.

Auto:

1. Steps 1 to 3 as for Yes.
2. Benchmark on GPU; if no GPU exists or it fails, benchmark on CPU.
3. The first passing device continues as Yes with that device.
4. If none passes: report the measurements, delete the models the setup downloaded, uninstall QMD only if the setup installed it, restore the configuration, store the selection as `false`, and continue as No.

No:

- Remove skill, hook, scripts, and instruction line; stop a running daemon.
- Remove the setup-owned QMD package and setup-owned models.
- Never remove a QMD installation, model, or collection the setup did not create.

Migration on the first update after this change:

- Remove the Python installation: `~/.my-ai-configuration/semantic-retrieval/` (virtual environment, model cache, data), its daemon, and `semantic-retrieval.json`.
- Remove previous QMD extension records (Claude plugin `qmd@qmd`, Codex QMD record) from the extension state. If the answer is Yes or a passing Auto, the existing npm package is adopted by the new path instead of being uninstalled.

Dry run: print every step as `DRYRUN ...`; no download, benchmark, or removal.

## Auto benchmark

- Fixture: a small fixed document set shipped with the scripts, indexed into a temporary named index (`qmd --index ai-config-benchmark`), removed afterwards.
- Models are warmed before measuring.
- Search: median latency of three `qmd query` runs with expansion, vector search, and reranking of 40 candidates must be at most 5 s (`QMD_BENCHMARK_MAX_QUERY_SECONDS`).
- Indexing: embedding throughput must be at least 20 chunks per second (`QMD_BENCHMARK_MIN_CHUNKS_PER_SECOND`).
- Order: GPU first, then CPU. Timeout per device: 10 minutes; a timeout fails that device.
- Result: JSON `{device, querySeconds, chunksPerSecond, passed}` per measured device, printed in the install summary.

## Runtime

SessionStart hook (Claude and Codex, `.sh` and `.ps1`):

- Runs only inside a Git repository. Starts `qmd-warm.mjs` detached and returns immediately with exit code 0.
- Errors go to `~/.my-ai-configuration/logs/qmd-warm.log`; the hook never blocks or fails a session.

Search (`qmd-search.mjs`):

1. Refresh the repository collection when files changed since the last refresh (`git status` and modification times), then `qmd embed` for it.
2. Query the daemon; start it if it is not running; fall back to `qmd query --json` when the daemon cannot be reached or started.
3. Print the JSON results.

Strict skill:

- Description: "MUST use before reading or grepping code whenever the exact symbol, file, or string is not already known: concept questions, unfamiliar areas, 'where/how is X done', bug reports that describe behavior. Use rg only for known identifiers, paths, or exact strings."
- Body: search first with a full behavioral question; open and verify the top hits; then use `rg` for callers and tests. If no relevant hit appears, run one rephrased search before switching to `rg`. The previous cost check (`status`, repository-size thresholds) is removed.

Global instruction line (only when the skill is installed): "When `semantic-search` is installed, run it first for any question whose identifiers are unknown; fall back to `rg` with a brief note only if it fails."

## Error handling

- Model download or `npm` failure during install or update: roll back what this run created. Yes fails the install; Auto treats it as unsuitable and reports the reason.
- Benchmark hang: per-device timeout of 10 minutes.
- Hook: detached, logged, always exit code 0. `qmd embed` uses QMD's 30-minute session cap and resumes incrementally on the next start.
- Wrapper failure: non-zero exit with a short message on stderr; the skill continues with `rg` and states the limitation.
- Stale `daemon.json` (process gone or token rejected): the wrapper deletes it and starts a new daemon; if that fails it uses the CLI fallback.
- `index.yml` that cannot be parsed: abort without writing.

## Testing

- Node unit tests (`node --test`): collection name and mask, benchmark decision (thresholds, GPU before CPU, unsuitable result), daemon idle exit with an injected clock, token rejection, wrapper fallback to the CLI, `index.yml` merge preserving foreign keys.
- Install guard tests in Bash and PowerShell with a mocked `qmd`: Yes, No, Auto pass and fail, dry run, ownership (a foreign QMD survives No), migration (Python installation removed), skill, hook, and instruction line present only when enabled.
- Integration job replacing the `retrieval` CI job: install QMD, pull models (cached), index a small fixture, assert the wrapper returns the expected hit, start and stop the daemon.
- `ab.py`: the `setup-no-search` arm and `--warm-index` use the QMD path.
- `prompt-budget`: the longer skill description changes the baseline; update it deliberately and report the difference.

## Risks to verify during implementation

- Whether the Codex `workspace-write` sandbox can reach the daemon on `127.0.0.1` and read `~/.cache/qmd`. If not, the Codex skill needs an approval rule for the wrapper or must run it outside the sandbox.
- Whether `qmd doctor`'s device probe is reliable enough to choose `gpu` for Yes without a benchmark.
- Disk and VRAM use: about 2.4 GB of models; the daemon holds them in VRAM until the idle stop.

## Out of scope

- Commands for managing user collections; users register them with `qmd collection add`.
- Any MCP integration of QMD.
