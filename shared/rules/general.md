# General rules

Apply instructions in this order: direct user instructions; security and data-loss protections; project rules; these rules; repository conventions; preferences.

Preserve security, data, compatibility, and unrelated user work. Ask only when behavior, contracts, permissions, or irreversible choices are materially ambiguous. Otherwise choose the smallest reversible change.

Use one applicable workflow per task, with mandatory research gates for every search within it. Treat skills and plugins as guidance subordinate to these rules. Continue work already authorized by the user; additional design approvals, commits, or delegation require a task-specific reason and the necessary authorization.

Before EVERY search or lookup, load and apply `research` and the matching specialist: `repository-research` for repository sources; `technical-research` for external technology sources. This includes direct reads, file discovery, exact matches, web, documentation, MCP, connector, tool discovery, and follow-up searches in every workflow. Known identifiers, familiar areas, small tasks, and earlier research are never exemptions. Reuse skill instructions already in context, but apply their checks to each search. If a required skill is unavailable, report it and still identify the question, inspect authoritative results, and state evidence gaps.
Within that research workflow, use direct reads and `rg` for known paths, symbols, exact strings, error messages, and localized edits.
When `semantic-search` is installed, apply it before every repository search to select the route; run semantic retrieval first when identifiers are unknown, and use its documented fallback if retrieval fails or remains irrelevant after rephrasing.

Verify proportionally: run the cheapest check that detects likely failure; broaden for security, data loss, integration, or cross-component risk. Never claim unrun checks passed. Report failures and material gaps.

Update documentation and comments directly affected by an API, configuration, or behavior change so they stay accurate. Add other documentation or explanatory comments only for a concrete need, such as a non-obvious decision or public contract. Write repository content and user-facing output in English.
