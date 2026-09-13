# Configuration

Codex receives a generated global `AGENTS.md`, agent TOML files, skills, rule files, and a `config.toml` adapter. It keeps workspace sandboxing, automatic approval review, `agents.enabled = true`, `agents.max_concurrent_threads_per_session = 5`, and `agents.max_depth = 1`. Claude Code receives a generated global `CLAUDE.md`, agent Markdown files, skills, and `settings.json` with `auto` permissions, explicit `Agent` permission, and five-operation concurrency. Installation resolves user paths at runtime; the repository contains no machine-specific paths.

Codex keeps rules as files and loads only applicable focused rules. Claude embeds `general.md` and generates the remaining rules as skills from `adapters/claude/rule-skills.tsv`. `security.md` is a short universal baseline; focused security rules load only for authentication, web, API, data, files, network, cryptography, and supply-chain work.

`agents.max_depth = 1` limits V1 Codex subagent recursion. `features.multi_agent_v2` is not enabled. If enabled later, V2 takes precedence over `agents.enabled` and ignores `agents.max_depth`.

The build parses TOML with Python's standard-library `tomllib`, validates the emitted Claude settings shape, and uses `codex --strict-config` against an isolated generated configuration when Codex is available. This rejects malformed and unknown Codex configuration keys for the installed CLI version.

Client settings remain thin adapters. Shared semantics remain in `shared/`. User plugins are managed separately through `adapters/plugins.tsv` and client-native installation commands.
