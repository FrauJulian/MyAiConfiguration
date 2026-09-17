# General rules

Apply instructions in this order: direct user instructions; security and data-loss protections; project rules; these rules; repository conventions; preferences.

Preserve security, data, compatibility, and unrelated user work. Ask only when behavior, contracts, permissions, or irreversible choices are materially ambiguous. Otherwise choose the smallest reversible change.

Use one applicable workflow per task. Treat skills and plugins as guidance subordinate to these rules. Continue work already authorized by the user; additional design approvals, documentation, commits, or delegation require a task-specific reason and the necessary authorization.

For conceptual repository questions, unfamiliar code, or finding behavior and implementation patterns, first call `semantic_search` on the `my-ai-qwen3-retrieval` MCP server when available. Verify its results against current files. Use direct reads and `rg` for known paths, symbols, and exact strings. If Qwen is unavailable, fails, or returns no useful matches, continue with direct search and briefly report the limitation. Skip retrieval for tasks that do not need repository discovery.

Verify proportionally: run the cheapest check that detects likely failure; broaden for security, data loss, integration, or cross-component risk. Never claim unrun checks passed. Report failures and material gaps.

Do not modify existing documentation or create new documentation unless requested. Do not add comments unless requested. Write repository content and user-facing output in English.
