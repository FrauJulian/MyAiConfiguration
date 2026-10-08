# Configuration

Source templates are [`adapters/codex/config/config.toml`](../adapters/codex/config/config.toml)
and [`adapters/claude/config/settings.json`](../adapters/claude/config/settings.json).
Installation targets `~/.codex` and `~/.claude`; Codex skills go to `~/.agents/skills`.
Choose the PowerShell or Bash package independently of the client.

Codex receives a generated global `AGENTS.md`, agent TOML files, skills, rule files, and a `config.toml` adapter.
It sets workspace sandboxing with shell network access, automatic approval review, `agents.enabled = true`,
`agents.max_concurrent_threads_per_session = 5`, and `agents.max_depth = 1`.

Claude Code receives a generated global `CLAUDE.md`, agent Markdown files, skills, and `settings.json` with
`auto` permissions and explicit `Agent` and `mcporter call context7.*` shell permissions. Where enabled, its sandbox
allows the `mcp.context7.com` domain. The adapter sets a five-operation concurrency default, at most five concurrent
subagents (`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`), and a spawn depth of one (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`).
Installation resolves user paths at runtime. Active session policy can further restrict these defaults.

Both clients embed `shared/rules/general.md` and the rule-loading conditions from `shared/global-instructions.md`. Rules for languages and frameworks live in their own directories, with an `index.md` entry point and focused Markdown rules under `references/`. Security has its own directory with a baseline entry point and focused rules for authentication, web, APIs, data, files, network, cryptography, and supply chains. Git, Microsoft, and cross-cutting rules remain directly under `shared/rules/`. Codex receives the full directory tree; Claude generates a skill for each rule and copies supporting references alongside the index skill.

The Codex adapter sets `agents.max_depth = 1` and does not enable `features.multi_agent_v2`. Shared instructions also prohibit subagents from creating further subagents. Agent roles are optional, not stages that every task must run.

The build parses TOML with Python's standard-library `tomllib`, validates the emitted Claude settings shape, and uses `codex --strict-config` against an isolated generated configuration when Codex is available. This rejects malformed and unknown Codex configuration keys for the installed CLI version.

Client settings remain thin adapters. Shared semantics remain in `shared/`. User plugins are managed separately through `adapters/plugins.tsv` and client-native installation commands.

## Permission defaults

Codex sets `approval_policy = "on-request"`, `approvals_reviewer = "auto_review"`, and `sandbox_mode = "workspace-write"`. Eligible approval requests go through automatic review. Claude sets `permissions.defaultMode = "auto"` and shell-specific deny rules. Its sandbox is enabled on supported macOS, Linux, and WSL2 environments and disabled where unavailable, including native Windows. These are generated defaults, not a guarantee that a running session, account policy, or explicit launch override uses the same mode.

On native Windows, the Codex adapter selects `windows.sandbox = "elevated"`, the [recommended Windows sandbox](https://learn.chatgpt.com/docs/windows/windows-sandbox). Its setup may require administrator approval; sandboxed commands run as dedicated lower-privilege users. The previous `unelevated` default reproduced `spawnSync git EPERM` when QMD's Node wrapper captured child-process output through pipes. The configuration change preserves workspace boundaries, network settings, and automatic approval review. Apply the generated configuration through the normal update process, complete Codex's sandbox setup if prompted, and start a new session. Verify semantic search there; package validation cannot establish runtime pipe compatibility. Use `unelevated` only as an explicit local fallback when elevated setup is unavailable, with that compatibility limitation in mind.

## Status displays

Codex's native `tui.status_line` contains `model`, `reasoning`, `fast-mode`, `approval-mode`, `five-hour-limit`, `weekly-limit`, `project-name`, `git-branch`, `context-window-size`, `context-used`, and `used-tokens`, in that order. `fast-mode` shows `Fast on` or `Fast off` for supported models; it does not change the selected mode. `five-hour-limit` and `weekly-limit` show remaining usage in the primary and secondary quota windows, typically five hours and one week, and are omitted when Codex has no quota data. `approval-mode` reports the active command review mode. Rendering and colors are controlled by Codex; the adapter does not define custom colors per field. These native fields are supported by [Codex 0.161.0](https://github.com/openai/codex/blob/rust-v0.161.0/codex-rs/tui/src/chatwidget/status_surfaces.rs).

Claude runs `shared/statusline/statusline.ps1` for PowerShell or `statusline.sh` for Bash. Its two-line display is:

```text
Opus · Review auto · Effort high · MyRepo @ main
Ctx 200k · Used 42% · Tokens 16.7k
```

Model and context-window size are cyan, effort and cumulative tokens magenta, repository blue, and branch green. Context usage is green below 60%, yellow from 60%, and red from 85%, using the rounded displayed percentage. A nonempty `NO_COLOR` disables ANSI colors. The Bash implementation requires `jq`.

`Ctx` is the context-window capacity; `Used` is the reported percentage occupied. `Tokens` adds the session's reported total input and output tokens, not just the current context. Counts use `k` and `M` suffixes. Missing model, effort, context size, or percentage is shown as `-`; missing token totals start at zero. Repository names fall back to the Git root or current directory; unavailable branches show `-`.

Claude's status line displays `permission_mode` or `permissionMode` when Claude provides it, and otherwise shows the configured `auto` review mode.

## Local QMD search

Install and update offer **Yes / No / Auto**, with No as the initial default. This option is separate
from the extension selector. The saved `semantic_retrieval` key keeps its name for compatibility.
Quickupdate reuses the saved choice and device; it does not rerun the benchmark.

- **Yes:** install `@tobilu/qmd@2.8.3` if QMD is absent, copy the shared runtime scripts, configure
  and download the three models, and choose GPU when detected or CPU otherwise. An existing QMD
  installation is reused, not upgraded by this step.
- **Auto:** prepare the same dependencies, then benchmark GPU when available and CPU if needed.
  Both thresholds must pass: median warm search latency at most 5 seconds and embedding throughput
  at least 20 chunks/second. Each device has a 10-minute timeout. No passing device disables search
  and triggers setup-owned resource cleanup. Auto can download models while answering the setup prompt.
- **No:** omit the search skill and its instruction line, remove the warm-up hook registration,
  and disable search for the selected clients. Dry runs do not download, benchmark, or remove QMD resources.

The models are Qwen3-Embedding-0.6B, Qwen3-Reranker-0.6B, and QMD Query Expansion 1.7B.
Exact model URIs live in [`shared/qmd/qmd-lib.mjs`](../shared/qmd/qmd-lib.mjs).
Auto thresholds can be overridden with `QMD_BENCHMARK_MAX_QUERY_SECONDS` and
`QMD_BENCHMARK_MIN_CHUNKS_PER_SECOND`. The benchmark uses a temporary database and a deterministic
100-document fixture; its measurements are not an end-to-end estimate for a user's repository.

### Search and storage

The `semantic-search` skill calls the installed wrapper from the current Git repository:

```text
node "$HOME/.my-ai-configuration/qmd/qmd-search.mjs" --query "Where are temporary upload failures retried?" --top-k 5
```

This command works in PowerShell and Bash. `--root` selects a repository explicitly. Results are JSON
objects with `path`, `line`, `score`, and `snippet`; repository hits use relative paths and other collections
use `qmd://` URIs. Known identifiers still use direct reads or `rg`; unknown identifiers use semantic retrieval first.

A token-protected daemon listens on `127.0.0.1`, refreshes changed repository collections, skips git-ignored
paths, and searches the current repository together with the user's default QMD collections. Repository
collections use `repo-` followed by a 12-character path hash. A SessionStart hook warms the daemon and index
in the background. Models stay loaded until the daemon stops after 30 idle minutes, configurable with
`QMD_IDLE_MINUTES`.

On daemon failure the wrapper tries the QMD CLI against the current repository collection only. This fallback
requires an existing index; it does not create or refresh the collection. If the wrapper fails, the skill
reports the limitation and continues with `rg`.

| Location | Contents |
| --- | --- |
| `~/.my-ai-configuration/qmd/` | Runtime scripts, daemon state, locks, collection ownership, and `warm.log`. |
| `~/.my-ai-configuration/qmd.json` | Selected device, enabled clients, and setup ownership records. |
| `$XDG_CACHE_HOME/qmd/` (default `~/.cache/qmd/`) | Shared `index.sqlite` and model cache. |
| `$QMD_CONFIG_DIR/index.yml` | Configuration when `QMD_CONFIG_DIR` is set; otherwise `$XDG_CONFIG_HOME/qmd/index.yml`, defaulting to `~/.config/qmd/index.yml`. |

Codex's adapter grants writable roots for `~/.my-ai-configuration/qmd` and `~/.cache/qmd`.
A custom cache location needs a matching writable root. QMD also writes its configuration when registering
collections and persisting ignore lists; the resolved configuration directory must be writable under the
active sandbox. These adapter roots do not themselves grant access to `~/.config/qmd`.

Disabling search or uninstalling one client keeps the shared runtime while another client remains enabled.
After the last client disables it, cleanup stops the daemon, removes recorded repository collections and
setup-owned models/package, restores the previous `models:` block, and removes the runtime scripts.
It preserves foreign QMD installations, models, collections, and the shared database. Failed cleanup can leave
resources behind; inspect reported warnings rather than deleting the whole cache. Updates also migrate the
old setup-owned Python retrieval directory and QMD extension ownership records.

### Verification and troubleshooting

Check `~/.my-ai-configuration/qmd/warm.log` for background warm-up errors. First startup or changed repositories
can take longer than a warm query. Windows sandbox setup and child-process pipe restrictions can prevent
repository discovery or daemon startup; see [Permission defaults](#permission-defaults).

Model-free unit tests do not verify downloads, GPU support, sandbox access, or real search quality.
See [QMD tests](scripts.md#qmd-tests) for the separate test commands and dependency setup.

## Verification and installation

The agent chooses the smallest sufficient checks based on behavior, affected callers, risk, reversibility, and uncertainty. Inspection can suffice for a small change. Full builds, broad test suites, and independent reviews are not automatic; explicit user and project requirements remain binding.

Delegation and long-running state use the shared orchestration rule, loaded on demand as a Codex rule or Claude skill. The coordinator owns decisions and routes concise evidence-based handoffs. Review and execution verification have separate responsibilities; see [Agents](agents.md).

Rebuild packages after changes to shared definitions or adapters. Generated defaults reach a user's configuration only through installation or update. Updates merge Codex's setup-owned root keys and table fields while retaining other root keys, extra fields in managed tables, plugin and marketplace tables, other unmanaged tables such as `mcp_servers` and `model_providers`, and unowned array tables. Claude settings retain unrelated keys and hooks. See [the README](../README.md) for overwrite and backup behavior.
