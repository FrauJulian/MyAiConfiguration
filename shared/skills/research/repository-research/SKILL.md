---
name: repository-research
description: MUST use before changing, reviewing, or answering questions about any repository area not yet read in this session; trace files, callers, behavior, tests, and conventions. Not for external technology questions (use technical-research).
---

# Repository Research

Understand an existing repository area before changing it or answering a codebase-specific question. Do not edit or answer from memory of an area you have not read in this session.

## Workflow

1. Locate the entry point. Known path, symbol, exact string, or configuration key: read it directly or search with `rg`. Unknown identifiers: run `semantic-search` first when it is installed.
2. Trace the flow from entry point through shared helpers to observable behavior. Search callers and tests of every symbol you will change.
3. Check related implementations, tests, configuration, and documentation. Note established conventions and where they differ across clients, shells, or platforms.
4. When the change depends on an external library, API, tool version, or standard whose behavior you have not verified, continue with `technical-research` for that part.
5. Report file paths and symbols as evidence. Separate confirmed behavior, inference, and unresolved questions.

Return the relevant architecture, existing patterns, affected areas, and unknowns. Do not change implementation code during research unless asked.
