# Configuration

Codex receives a generated global `AGENTS.md`, agent TOML files, skills, and a `config.toml` adapter with workspace sandboxing, interactive approval boundaries, automatic approval review, enabled sub-agents, and a five-thread concurrency limit. Claude Code receives a generated global `CLAUDE.md`, agent Markdown files, skills, and `settings.json` with the `auto` permission mode, explicit `Agent` permission, and a five-operation tool/sub-agent concurrency limit. The exact installed locations are resolved from the user profile at install time; no machine-specific absolute path is stored in the repository.

Neither current client configuration model exposes a supported global `max_depth` setting. The repository does not emit an unsupported key that would be ignored or cause configuration validation errors.

Client settings remain thin adapters. Shared semantics remain in `shared/`.

User plugins are managed separately through `adapters/plugins.tsv` and the client-native plugin commands. They are not copied into `generated/` because each client owns its plugin cache and authentication state.
