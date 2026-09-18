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
| `commands/build.ps1`, `commands/build.sh` | Generate the four client packages in `generated/`. |
| `commands/check-capabilities.ps1`, `commands/check-capabilities.sh` | Check required tools and versions. |
| `commands/install.ps1`, `commands/install.sh` | Install a selected client configuration. |
| `commands/update.ps1`, `commands/update.sh` | Update an existing installation; Quick reuses saved choices. |
| `commands/uninstall.ps1`, `commands/uninstall.sh` | Remove setup-owned configuration and extensions. |
| `commands/doctor.ps1`, `commands/doctor.sh` | Check generated output and installed configuration. |
| `commands/prompt-budget.ps1`, `commands/prompt-budget.sh` | Check generated instruction sizes against their budget. |
| `commands/repository-context.ps1`, `commands/repository-context.sh` | Refresh the local repository-context cache. |
| `commands/session-state.ps1`, `commands/session-state.sh` | Read or update the local agent session state. |
| `commands/telemetry.ps1`, `commands/telemetry.sh` | Append a local telemetry event. |

Qwen retrieval uses `shared/retrieval/benchmark.py`; run it through `scripts/lib/semantic-retrieval.py benchmark --root . --home <home-directory>`.

## Checks and tests

| Script | Purpose |
| --- | --- |
| `checks/validate-config.py` | Validate generated Codex TOML and Claude JSON. |
| `tests/test-build-validation.ps1`, `tests/test-build-validation.sh` | Validate build failures and generated output. |
| `tests/test-install-guards.ps1`, `tests/test-install-guards.sh` | Validate install and update guard conditions. |
| `tests/test-install-options.py` | Validate interactive option handling and generated manifest changes. |
| `tests/test-managed-extensions.py` | Validate plugin, skill, and CLI ownership handling. |
| `tests/test-managed-install.ps1`, `tests/test-managed-install.sh` | Validate managed-file synchronization and backups. |
| `tests/test-plugin-selection.ps1`, `tests/test-plugin-selection.sh` | Validate plugin selection. |
| `tests/test-prompt-inventory.py` | Validate prompt inventory collection. |
| `tests/test-quick-update.py` | Validate saved Quickupdate choices. |
| `tests/test-quick-update.ps1`, `tests/test-quick-update.sh` | Run the Quickupdate test through the relevant shell. |
| `tests/test-retrieval-server.py` | Validate retrieval indexing, ranking, and optional real-model execution. |
| `tests/test-semantic-retrieval.py` | Validate retrieval installation and removal. |
| `tests/test-session-state.py` | Validate session-state helpers. |
| `tests/test-shell-packages.ps1`, `tests/test-shell-packages.sh` | Validate generated packages and shell entry points. |
| `tests/test-telemetry.py` | Validate telemetry output. |

## Internal helpers

| Script | Purpose |
| --- | --- |
| `lib/install-options.ps1`, `lib/install-options.sh` | Read installation options and calculate client-specific choices. |
| `lib/install-options.py` | Filter configuration templates according to installation options. |
| `lib/install-targets.ps1`, `lib/install-targets.sh` | Resolve configuration targets for the selected client and shell. |
| `lib/manifest.ps1`, `lib/manifest.sh` | Synchronize managed files and their ownership manifest. |
| `lib/plugins.ps1`, `lib/plugins.sh` | Select and install configured plugins. |
| `lib/managed-extensions.py` | Reconcile CLI extensions and MCPorter-managed plugins. |
| `lib/prompt-inventory.py` | Collect prompt files for the build. |
| `lib/selection-state.ps1`, `lib/selection-state.sh` | Persist choices used by Quickupdate. |
| `lib/selection-state.py` | Read and write Quickupdate state. |
| `lib/semantic-retrieval.ps1`, `lib/semantic-retrieval.sh` | Invoke semantic retrieval from the installation flow. |
| `lib/semantic-retrieval.py` | Install, index, benchmark, and remove the local retrieval service. |
| `shared/retrieval/benchmark.py` | Measure Qwen embedding and reranking speed for the Auto recommendation. |
