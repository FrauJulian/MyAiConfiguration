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
| `commands/repository-context.ps1`, `commands/repository-context.sh` | Refresh the local repository-context cache. |
| `commands/session-state.ps1`, `commands/session-state.sh` | Read or update the local agent session state. |
| `commands/telemetry.ps1`, `commands/telemetry.sh` | Append a local telemetry event. |
| `commands/add-instruction.ps1`, `commands/add-instruction.sh` | Append a client-specific user instruction outside managed configuration. |
| `commands/remove-instruction.ps1`, `commands/remove-instruction.sh` | Remove the last exact matching instruction block for a selected client. |
| `commands/add-credentials.ps1`, `commands/add-credentials.sh` | Store a client-scoped tool credential in the operating-system credential store. |
| `commands/remove-credentials.ps1`, `commands/remove-credentials.sh` | Delete a selected client-scoped credential from the operating-system credential store. |

Prompt KPIs estimate tokens as UTF-8 bytes divided by four, using the larger shell package per client. Skill metadata counts `SKILL.md` frontmatter outside rule skills; the rule catalog counts all generated rule entry files but excludes references, so it measures the available catalog size rather than rules loaded in a typical session; agent metadata counts frontmatter for Claude and `name`/`description` for Codex. All metrics fail CI above baseline +10%; permanent context also warns above 10,000 tokens and fails above 15,000 tokens. The baseline covers the retained skill catalog. Project-specific instructions, external plugin prompt bodies, and live MCP/tool schemas are not measured.

Custom instructions are read before generated rules, skills, and plugins. They remain under `~/.my-ai-configuration/instructions/`, so installation and update scripts never manage or reset them.
To undo an added instruction, pass the same text to `remove-instruction` with `-Client`/`--client` and `-Instruction`/`--instruction`. It removes the last exact matching block per selected client and preserves other text. A missing match leaves the file unchanged.

Credential commands currently require PowerShell and Windows Credential Manager, including their Bash wrappers. Use `~/.my-ai-configuration/bin/with-credential.ps1` or `.sh` to run a tool with a stored key available only in that child process. The key must be a valid environment-variable name; its value is never written to configuration.
Use `remove-credentials` with `-Client`/`--client` and `-Key`/`--key` to delete only that credential. The shared `with-credential` helpers remain installed for other keys.

Qwen Auto selection uses `shared/retrieval/benchmark.py`; run it through `scripts/lib/semantic-retrieval.py benchmark --root . --home <home-directory>`. This warm-model check uses synthetic, repeated short documents. Its result does not measure model startup, first indexing, real code chunks, CLI latency, or memory use; do not use it as an end-to-end performance estimate.

## Checks and tests

Gitea Actions runs the repository checks from `.gitea/workflows/ci.yml`.

| Script | Purpose |
| --- | --- |
| `checks/validate-config.py` | Validate generated Codex TOML and Claude JSON. |
| `tests/test-build-validation.ps1`, `tests/test-build-validation.sh` | Validate build failures and generated output. |
| `tests/test-capabilities.ps1` | Guard PowerShell capability detection. |
| `tests/test-install-guards.ps1`, `tests/test-install-guards.sh` | Validate install and update guard conditions. |
| `tests/test-install-options.py` | Validate interactive option handling and generated manifest changes. |
| `tests/test-managed-extensions.py` | Validate plugin, skill, and CLI ownership handling. |
| `tests/test-managed-install.ps1`, `tests/test-managed-install.sh` | Validate managed-file synchronization and backups. |
| `tests/test-plugin-selection.ps1`, `tests/test-plugin-selection.sh` | Validate plugin selection. |
| `tests/test-prompt-budget.py` | Validate prompt budget threshold evaluation. |
| `tests/test-prompt-inventory.py` | Validate prompt inventory collection. |
| `tests/test-quick-update.py` | Validate saved Quickupdate choices. |
| `tests/test-remove-customizations.py` | Validate targeted instruction and credential removal without accessing the real credential store. |
| `tests/test-quick-update.ps1`, `tests/test-quick-update.sh` | Run the Quickupdate test through the relevant shell. |
| `tests/test-retrieval-server.py` | Validate retrieval indexing, ranking, and optional real-model execution. |
| `tests/test-semantic-retrieval.py` | Validate retrieval installation and removal. |
| `tests/test-session-state.py` | Validate session-state helpers. |
| `tests/test-shell-packages.ps1`, `tests/test-shell-packages.sh` | Validate generated package contents and client settings. |
| `tests/test-runtime-status.ps1`, `tests/test-runtime-status.sh` | Validate build summaries and status-line output. |
| `tests/test-install-selections.ps1`, `tests/test-install-selections.sh` | Validate dry-run shell and client selections. |
| `tests/test-command-summaries.ps1`, `tests/test-command-summaries.sh` | Validate doctor, install, and update summary output. |
| `tests/test-telemetry.py` | Validate telemetry output. |
| `tests/test-user-customizations.py` | Validate user instruction overlays and credential helpers. |

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
| `lib/semantic-retrieval.ps1`, `lib/semantic-retrieval.sh` | Invoke semantic retrieval from the installation flow. |
| `lib/semantic-retrieval.py` | Install, index, benchmark, and remove the local retrieval service. |
| `shared/retrieval/benchmark.py` | Check warm Qwen embedding and reranking speed for Auto selection; not an end-to-end benchmark. |
