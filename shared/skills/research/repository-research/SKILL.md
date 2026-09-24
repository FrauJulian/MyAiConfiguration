---
name: repository-research
description: Use for codebase-specific questions or before changing an unfamiliar area; trace existing files, callers, behavior, tests, and conventions. Do not use for general external technology research.
---

# Repository Research

Use to understand an existing repository area before changing it or answering a codebase-specific question.

## Workflow

1. Start from known paths, symbols, exact strings, or configuration keys. Read relevant files directly and search callers with repository-native tools.
2. Trace the flow from entry point through shared helpers to observable behavior. Check related implementations, tests, configuration, and documentation.
3. Identify established conventions and note where they differ across clients, shells, or platforms.
4. Use semantic search only when terminology is unclear, the flow spans components, or direct search has not found the relevant code. Confirm any retrieved result against current files.
5. Report file paths and symbols as evidence. Separate confirmed behavior, inference, and unresolved questions.

Return the relevant architecture, existing patterns, affected areas, and unknowns. Avoid changing implementation code during research unless asked.
