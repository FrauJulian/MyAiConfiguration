# Configuration

Codex receives a generated global `AGENTS.md`, agent TOML files, skills, rule files, and a `config.toml` adapter. It keeps workspace sandboxing, automatic approval review, `agents.enabled = true`, `agents.max_concurrent_threads_per_session = 5`, and `agents.max_depth = 1`. Claude Code receives a generated global `CLAUDE.md`, agent Markdown files, skills, and `settings.json` with `auto` permissions, explicit `Agent` permission, and five-operation concurrency. Installation resolves user paths at runtime; the repository contains no machine-specific paths.

Both clients embed `shared/rules/general.md` in their global instructions. Codex loads applicable focused rules from `rules/`; Claude generates them as skills from the shared `adapters/rule-skills.tsv` manifest. Angular, WPF, and UI/UX rules have small entry points with references loaded by topic. `security.md` is the baseline for programming tasks; focused security rules cover authentication, web, API, data, files, network, cryptography, and supply-chain work.

The Codex adapter sets `agents.max_depth = 1` and does not enable `features.multi_agent_v2`. Shared instructions also prohibit subagents from creating further subagents. Agent roles are optional, not stages that every task must run.

The build parses TOML with Python's standard-library `tomllib`, validates the emitted Claude settings shape, and uses `codex --strict-config` against an isolated generated configuration when Codex is available. This rejects malformed and unknown Codex configuration keys for the installed CLI version.

Client settings remain thin adapters. Shared semantics remain in `shared/`. User plugins are managed separately through `adapters/plugins.tsv` and client-native installation commands.

## Permission defaults

Codex sets `approval_policy = "on-request"`, `approvals_reviewer = "auto_review"`, and `sandbox_mode = "workspace-write"`. Eligible approval requests go through automatic review; sandboxing remains enabled. Claude sets `permissions.defaultMode = "auto"`. These are generated defaults, not a guarantee that a running session, account policy, or explicit launch override uses the same mode.

## Status displays

Codex's native `tui.status_line` contains `model`, `reasoning`, `permissions`, `approval-mode`, `project-name`, `git-branch`, `context-window-size`, `context-used`, and `used-tokens`, in that order. `permissions` reports the active permission profile or sandbox summary, and `approval-mode` reports the active command approval mode. Rendering and colors are controlled by Codex; the adapter does not define custom colors per field.

Claude runs `shared/statusline/statusline.ps1` for PowerShell or `statusline.sh` for Bash. Its two-line display is:

```text
Opus · Effort high · MyRepo @ main
Ctx 200k · Used 42% · Tokens 16.7k
```

Model and context-window size are cyan, effort and cumulative tokens magenta, repository blue, and branch green. Context usage is green below 60%, yellow from 60%, and red from 85%, using the rounded displayed percentage. A nonempty `NO_COLOR` disables ANSI colors. The Bash implementation requires `jq`.

`Ctx` is the context-window capacity; `Used` is the reported percentage occupied. `Tokens` adds the session's reported total input and output tokens, not just the current context. Counts use `k` and `M` suffixes. Missing model, effort, context size, or percentage is shown as `-`; missing token totals start at zero. Repository names fall back to the Git root or current directory; unavailable branches show `-`.

Claude Code reruns its status-line command when the permission mode changes, but does not pass that mode in the status-line JSON. Its line therefore does not show a configured default as though it were the active mode.

## Verification and installation

The agent chooses the smallest sufficient checks based on behavior, affected callers, risk, reversibility, and uncertainty. Inspection can suffice for a small change. Full builds, broad test suites, and independent reviews are not automatic; explicit user and project requirements remain binding.

Delegation and long-running state use the shared orchestration rule, loaded on demand as a Codex rule or Claude skill. The coordinator owns decisions and routes concise evidence-based handoffs. Review and execution verification have separate responsibilities; see [Agents](agents.md).

Rebuild packages after changes to shared definitions or adapters. Generated defaults reach a user's configuration only through installation or update. Updates back up replaced files and preserve Codex's local `model`, `reasoning_effort`, `plugins`, and `marketplaces` settings; other local settings are not generally merged. See [the README](../README.md) for overwrite and backup behavior.
