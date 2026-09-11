# Configuration

Codex receives a generated global `AGENTS.md`, agent TOML files, skills, rule files, and a `config.toml` adapter with workspace sandboxing, interactive approval boundaries, automatic approval review, enabled sub-agents, and a five-thread concurrency limit (`max_concurrent_threads_per_session`, the current canonical key; the legacy `max_threads` alias is not emitted). Claude Code receives a generated global `CLAUDE.md`, agent Markdown files, skills, and `settings.json` with the `auto` permission mode, explicit `Agent` permission, and a five-operation tool/sub-agent concurrency limit. The exact installed locations are resolved from the user profile at install time; no machine-specific absolute path is stored in the repository.

Claude's rule loading differs from Codex's by design: `general.md` is the only rule shipped as a plain, always-applied file (its text is also embedded directly in `CLAUDE.md`). Every technology- or situation-specific rule in `shared/rules/` is instead generated as a skill under `skills/rules/`, driven by `adapters/claude/rule-skills.tsv` (rule file, skill name, trigger description). Only a skill's name and description are ever permanently in context; Claude loads the full rule text only when it invokes the skill. Codex is unaffected — it keeps receiving every rule as a plain file and is told to load the matching one by path, exactly as before.

Neither current client configuration model exposes a supported global `max_depth` setting. The repository does not emit an unsupported key that would be ignored or cause configuration validation errors.

Client settings remain thin adapters. Shared semantics remain in `shared/`.

User plugins are managed separately through `adapters/plugins.tsv` and the client-native plugin commands. They are not copied into `generated/` because each client owns its plugin cache and authentication state.
