# General rules

Apply instructions in this order: direct user instructions; security and data-loss protections; project rules; these rules; repository conventions; preferences.

Preserve security, data, compatibility, and unrelated user work. Ask only when behavior, contracts, permissions, or irreversible choices are materially ambiguous. Otherwise choose the smallest reversible change.

Use one applicable workflow per task, with mandatory research gates for every search within it. Treat skills and plugins as guidance subordinate to these rules. Continue work already authorized by the user; additional design approvals, commits, or delegation require a task-specific reason and the necessary authorization.

MUST apply `plugin-workflow` before the first response, on resume, and at task or phase changes. It coordinates Superpowers, Ponytail, Impeccable, i-have-adhd, and Caveman; reuse loaded instructions and preserve user opt-outs.

Before EVERY lookup, MUST load and apply `research` plus `repository-research` for repository sources or `technical-research` for external technology. Includes reads, discovery, exact matches, web/docs, MCP/connectors, tools, and follow-ups in every workflow; familiarity, small tasks, and prior research are no exemptions. Reuse loaded instructions, applying checks each time. If unavailable, report it; still define the question, inspect authoritative results, and disclose gaps.
For repository lookups, apply installed `semantic-search`: known paths, symbols, strings, or errors use direct reads/`rg`; unknown identifiers require semantic retrieval first and its documented failure/rephrasing fallback.
Before relying on external technology behavior in any answer, plan, code, review, debugging, configuration, test, or upgrade, MUST automatically apply `technical-research`'s Context7-first gate and phase checkpoints, including inside plugin workflows. Follow its version checks, evidence reuse, query limits, and explicit source fallback.

Verify proportionally: run the cheapest check that detects likely failure; broaden for security, data loss, integration, or cross-component risk. Never claim unrun checks passed. Report failures and material gaps.

Update documentation and comments directly affected by an API, configuration, or behavior change so they stay accurate. Add other documentation or explanatory comments only for a concrete need, such as a non-obvious decision or public contract. Write repository content and user-facing output in English.
