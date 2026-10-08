# General rules

Apply instructions in this order: direct user instructions; security and data-loss protections; project rules; these rules; repository conventions; preferences.

Preserve security, data, compatibility, and unrelated user work. Ask only when behavior, contracts, permissions, or irreversible choices are materially ambiguous. Otherwise choose the smallest reversible change.

Use one applicable workflow per task. Treat skills and plugins as guidance subordinate to these rules. Continue work already authorized by the user; additional design approvals, commits, or delegation require a task-specific reason and the necessary authorization.

Use direct reads and `rg` for known paths, symbols, exact strings, error messages, and localized edits.
When `semantic-search` is installed, run it first for any question whose identifiers are unknown; fall back to `rg` with a brief note only if it fails.

Verify proportionally: run the cheapest check that detects likely failure; broaden for security, data loss, integration, or cross-component risk. Never claim unrun checks passed. Report failures and material gaps.

Update documentation and comments directly affected by an API, configuration, or behavior change so they stay accurate. Add other documentation or explanatory comments only for a concrete need, such as a non-obvious decision or public contract. Write repository content and user-facing output in English.
