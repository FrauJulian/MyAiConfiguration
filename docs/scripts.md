# Scripts

Run scripts from the repository root. PowerShell and Bash commands have equivalent behavior unless noted otherwise.

## Layout

| Directory | Purpose |
| --- | --- |
| `scripts/commands/` | User-facing build, installation, maintenance, and local utility commands. |
| `scripts/checks/` | Standalone configuration validation. |
| `scripts/tests/` | Repository verification scripts. |
| `scripts/lib/` | Internal helpers used by commands; do not invoke them directly. |

## Commands

| Script | Purpose |
| --- | --- |
| `commands/build.ps1`, `commands/build.sh` | Generate four client packages in `generated/` from the shared skill catalog. |
| `commands/check-capabilities.ps1`, `commands/check-capabilities.sh` | Check required tools and versions. |
| `commands/install.ps1`, `commands/install.sh` | Install a selected client configuration. |
| `commands/update.ps1`, `commands/update.sh` | Update an existing installation; Quick reuses saved choices. |
| `commands/uninstall.ps1`, `commands/uninstall.sh` | Remove setup-owned configuration and extensions. |
| `commands/doctor.ps1`, `commands/doctor.sh` | Check generated output and installed configuration. |
| `commands/prompt-budget.ps1`, `commands/prompt-budget.sh` | Track permanent context, skill metadata, the rule catalog, and agent metadata; warn above 10,000 permanent-context tokens, fail when any token estimate exceeds its baseline by 10%, or permanent context exceeds 15,000 tokens. |
| `commands/context-report.ps1`, `commands/context-report.sh` | Report the context installed Claude and Codex actually load, from Claude `/context`, `/skill-doctor`, and its init event, and Codex `debug prompt-input`: categories, active plugins, listed skills, installed skills missing from the listing, and skills listed without description context. `--check` fails on missing or description-less skills. No model request is made. |
| `commands/benchmark.ps1`, `commands/benchmark.sh` | Compare real Claude/Codex sessions with and without the setup. See [Session benchmarks](#session-benchmarks) for isolation, costs, and the search comparison. |
| `commands/repository-context.ps1`, `commands/repository-context.sh` | Refresh the local repository-context cache. |
| `commands/session-state.ps1`, `commands/session-state.sh` | Read or update the local agent session state. |
| `commands/telemetry.ps1`, `commands/telemetry.sh` | Append a local telemetry event. |
| `commands/add-instruction.ps1`, `commands/add-instruction.sh` | Append a client-specific user instruction outside managed configuration. |
| `commands/remove-instruction.ps1`, `commands/remove-instruction.sh` | Remove the last exact matching instruction block for a selected client. |
| `commands/add-credentials.ps1`, `commands/add-credentials.sh` | Store a client-scoped tool credential in the operating-system credential store. |
| `commands/remove-credentials.ps1`, `commands/remove-credentials.sh` | Delete a selected client-scoped credential from the operating-system credential store. |

Prompt KPIs estimate tokens as UTF-8 bytes divided by four, using the larger shell package per client.
Skill metadata counts every `SKILL.md` frontmatter, including Claude's generated rule skills. Permanent context
combines global instructions, skill and agent metadata, and the security baseline loaded for development tasks.
The rule catalog counts Codex rule files outside `references/` and Claude's generated `rules-*/SKILL.md` entries;
it measures available guidance, not all rules loaded in a typical session. Agent metadata counts Claude frontmatter
and Codex `name`/`description` fields. All metrics fail above baseline +10%; permanent context also warns above
10,000 tokens and fails above 15,000. Project instructions, external plugin bodies, and live MCP/tool schemas
are excluded. `context-report` complements this estimate with installed-client discovery.

Custom instructions remain under `~/.my-ai-configuration/instructions/`; installation and update scripts never reset their contents. Only clients with a nonempty instruction file receive a startup rule in their installed `AGENTS.md` or `CLAUDE.md`. That rule requires immediate loading before any response or task work and keeps the instructions active throughout the session, including after compaction. Adding or removing instructions refreshes the rule in an existing installation; empty or missing instruction files leave no rule. Generated packages contain no personal instruction rule. Changes apply when the client next loads its global instructions.
To undo an added instruction, pass the same text to `remove-instruction` with `-Client`/`--client` and `-Instruction`/`--instruction`. It removes the last exact matching block per selected client and preserves other text. A missing match leaves the file unchanged.

Credential commands currently require PowerShell and Windows Credential Manager, including their Bash wrappers. Use `~/.my-ai-configuration/bin/with-credential.ps1` or `.sh` to run a tool with a stored key available only in that child process. The key must be a valid environment-variable name; its value is never written to configuration.
Use `remove-credentials` with `-Client`/`--client` and `-Key`/`--key` to delete only that credential. The shared `with-credential` helpers remain installed for other keys.

The A/B benchmark measures whole sessions. Auto selection of local QMD search uses `shared/qmd/qmd-benchmark.mjs`, run through `scripts/lib/qmd.py`. It measures median search latency and embedding throughput on GPU, then CPU, and is not an end-to-end performance estimate.

## Checks and tests

Gitea Actions runs the repository checks from `.gitea/workflows/ci.yml`.

Doctor captures native-command diagnostics and checks exit codes. A warning on stderr does not abort the
PowerShell 5.1 script; failed version or configuration checks contribute to the final failure summary.
On Windows, an unavailable profile-folder lookup falls back to PowerShell's home path.

| Script | Purpose |
| --- | --- |
| `checks/validate-config.py` | Validate generated Codex TOML and Claude JSON. |
| `tests/test-build-validation.ps1`, `tests/test-build-validation.sh` | Validate build failures and generated output. |
| `tests/test-capabilities.ps1` | Guard PowerShell capability detection. |
| `tests/test-install-guards.ps1`, `tests/test-install-guards.sh` | Validate install and update guard conditions. |
| `tests/test-config-effects.py` | Check that generated limits and permissions take effect: Codex keeps the V1 multi-agent implementation that honors `agents.max_depth`; with `AI_CONFIG_LIVE_TESTS=1`, short Haiku sessions confirm that Claude withholds the Agent tool from subagents, refuses subagents above the concurrency limit, and blocks `git reset --hard` in every shell tool. |
| `tests/test-client-smoke.py` | Install a package into a temporary home with foreign settings and ask the installed Claude and Codex CLIs which skills, agents, and hooks they discover, without completing a model request. Skips a client whose CLI is unavailable unless `AI_CONFIG_REQUIRE_CLIENTS=1`, which the CI `client-smoke` job sets. |
| `tests/test-install-options.py` | Validate interactive option handling and generated manifest changes. |
| `tests/test-managed-extensions.py` | Validate plugin, skill, and CLI ownership handling. |
| `tests/test-managed-install.ps1`, `tests/test-managed-install.sh` | Validate managed-file synchronization and backups. |
| `tests/test-plugin-selection.ps1`, `tests/test-plugin-selection.sh` | Validate plugin selection. |
| `tests/test-prompt-budget.py` | Validate prompt budget threshold evaluation. |
| `tests/test-prompt-inventory.py` | Validate prompt inventory collection. |
| `tests/test-quick-update.py` | Validate saved Quickupdate choices. |
| `tests/test-remove-customizations.py` | Validate targeted instruction and credential removal without accessing the real credential store. |
| `tests/test-quick-update.ps1`, `tests/test-quick-update.sh` | Run the Quickupdate test through the relevant shell. |
| `tests/test-qmd-lib.mjs`, `test-qmd-daemon.mjs`, `test-qmd-search.mjs`, `test-qmd-warm.mjs`, `test-qmd-benchmark.mjs` | Model-free QMD unit tests; require the YAML dependency. |
| `tests/test-qmd-integration.mjs` | Manual integration test using real QMD and downloaded models; excluded from CI. |
| `tests/test-qmd-setup.py` | Validate QMD installation, migration, and removal. |
| `tests/test-session-state.py` | Validate session-state helpers. |
| `tests/test-shell-packages.ps1`, `tests/test-shell-packages.sh` | Validate generated package contents and client settings. |
| `tests/test-runtime-status.ps1`, `tests/test-runtime-status.sh` | Validate build summaries and status-line output. |
| `tests/test-install-selections.ps1`, `tests/test-install-selections.sh` | Validate dry-run shell and client selections. |
| `tests/test-command-summaries.ps1`, `tests/test-command-summaries.sh` | Validate doctor, install, and update summary output. |
| `tests/test-telemetry.py` | Validate telemetry output. |
| `tests/test-personal-instructions.py` | Validate startup instruction pointers and preservation of personal instruction files. |
| `tests/test-user-customizations.py` | Validate user instruction overlays and credential helpers. |

## QMD tests

The CI `qmd` job installs only `yaml@2.9.0` into an isolated directory, sets `QMD_PACKAGE_DIR` to that directory,
and runs these five files. It does not install QMD or download models. With a complete global QMD installation,
the same tests resolve YAML from QMD automatically:

```text
node --test scripts/tests/test-qmd-lib.mjs scripts/tests/test-qmd-daemon.mjs scripts/tests/test-qmd-search.mjs scripts/tests/test-qmd-warm.mjs scripts/tests/test-qmd-benchmark.mjs
```

Without QMD installed, use the dependency setup from [the CI workflow](../.gitea/workflows/ci.yml).
`QMD_PACKAGE_DIR` must point to the directory containing the test dependency's `node_modules` directory.
A missing YAML dependency fails `test-qmd-lib.mjs` before its tests load.

Run the integration test separately, only with a complete QMD installation and resources for model downloads.
Unset `QMD_CONFIG_DIR` first so the test uses its temporary configuration rather than an inherited user path.
Clear a unit-test-only `QMD_PACKAGE_DIR` override as well:

```text
node --test scripts/tests/test-qmd-integration.mjs
```

The integration test creates a temporary home and repository, downloads models, searches through the daemon,
and stops it after successful assertions.
Its temporary data is not automatically removed. `QMD_TEST_CACHE` can select an existing QMD cache parent;
the test uses its `qmd/` subdirectory, so avoid pointing it at a cache containing unrelated data.

## Session benchmarks

The A/B benchmark runs Python, C#/ASP.NET, and TypeScript tasks under `scripts/benchmarks/tasks/`.
These are real model sessions and can incur usage charges; `--dry-run` lists planned runs.
Both arms use the same model and reasoning effort for each client. Preflight records loaded configuration in
`provenance.json` and normally stops when the arms are not comparable. Reports compare pass rate, rework turns,
time, tokens, tool calls, cost, and workflow checks per task category.

For Claude's semantic-search comparison, pass these arguments to the shell's benchmark command:

```text
--clients claude --arms setup setup-no-search --tasks 11-* 12-* 13-* --warm-index
```

`setup-no-search` is Claude-only. Warm-up starts QMD and indexes the fixture before timing setup-arm sessions.
The Codex baseline requires a separate login under `--codex-baseline-home`; set `CODEX_HOME` to that path for
`codex login`. Supply `--codex-model` if the installed configuration does not select a model.
Benchmark fixture READMEs describe the starting task state and are retained as test inputs.

## Internal helpers

| Script | Purpose |
| --- | --- |
| `lib/install-options.ps1`, `lib/install-options.sh` | Read installation options and calculate client-specific choices. |
| `lib/credentials.ps1`, `lib/with-credential.sh` | Write a tool credential to Windows Credential Manager and expose it to one child process. |
| `lib/install-options.py` | Filter configuration templates and merge setup-owned client settings with local configuration. |
| `lib/install-targets.ps1`, `lib/install-targets.sh` | Resolve configuration targets for the selected client and shell. |
| `lib/manifest.ps1`, `lib/manifest.sh` | Synchronize managed files and their ownership manifest. |
| `lib/plugins.ps1`, `lib/plugins.sh` | Select and install configured plugins. |
| `lib/managed-extensions.py` | Reconcile CLI extensions and MCPorter-managed plugins. |
| `lib/prompt-inventory.py` | Report generated, installed, and cached skill counts for prompt-budget checks. |
| `lib/remove-instruction.py` | Remove an exact client-specific instruction block. |
| `lib/selection-state.ps1`, `lib/selection-state.sh` | Persist choices used by Quickupdate. |
| `lib/selection-state.py` | Read and write Quickupdate state. |
| `lib/qmd.sh`, `lib/qmd.ps1` | Invoke local QMD search from the installation flow. |
| `lib/qmd.py` | Install, migrate, benchmark, and remove local QMD search. |
| [`shared/qmd/`](../shared/qmd/) (repository root) | Installed QMD scripts: search CLI, daemon, warm-up, benchmark, and shared library. |
