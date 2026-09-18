# General rules

Apply instructions in this order: direct user instructions; security and data-loss protections; project rules; these rules; repository conventions; preferences.

Preserve security, data, compatibility, and unrelated user work. Ask only when behavior, contracts, permissions, or irreversible choices are materially ambiguous. Otherwise choose the smallest reversible change.

Use one applicable workflow per task. Treat skills and plugins as guidance subordinate to these rules. Continue work already authorized by the user; additional design approvals, documentation, commits, or delegation require a task-specific reason and the necessary authorization.

Start repository discovery with direct reads and `rg` for known paths, symbols, exact strings, localized changes, configuration edits, and routine checks. Use the installed semantic retrieval CLI only when terminology is unknown, the question spans multiple components, or direct search did not locate the relevant flow: `python ~/.my-ai-configuration/semantic-retrieval/server.py search --root . --data-dir ~/.my-ai-configuration/semantic-retrieval/data --model-cache ~/.my-ai-configuration/semantic-retrieval/model-cache --query "..." --top-k 5`. Each uncached search uses Qwen3-Embedding-0.6B for candidate retrieval and Qwen3-Reranker-0.6B for final ranking; reuse the cache for repeated unchanged queries and verify results against current files. If Qwen is unavailable, fails, or returns no useful matches, continue with direct search and briefly report the limitation.

Verify proportionally: run the cheapest check that detects likely failure; broaden for security, data loss, integration, or cross-component risk. Never claim unrun checks passed. Report failures and material gaps.

Do not create documentation or explanatory comments without a clear need. Update existing documentation or comments only when directly affected by an API, configuration, or behavior change and necessary to keep them accurate. Write repository content and user-facing output in English.
