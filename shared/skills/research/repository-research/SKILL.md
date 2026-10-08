---
name: repository-research
description: MUST use before EVERY repository search or lookup, including direct reads, file discovery, exact strings, known symbols, familiar areas, and follow-up searches in any workflow; also before repository changes, reviews, or answers.
---

# Repository Research

Apply `research` and this skill to every repository lookup. Earlier inspection and known identifiers do not waive the workflow. Reuse loaded instructions, but check the question, scope, and evidence for each lookup. Ground changes and answers in current files.

## Workflow

1. Identify the question and search scope, then locate the entry point. Apply `semantic-search` when installed to select the route. Known path, symbol, exact string, or configuration key: read it directly or search with `rg`. Unknown identifiers: run semantic retrieval first.
2. Trace the flow from entry point through shared helpers to observable behavior. Search callers and tests of every symbol you will change.
3. Check related implementations, tests, configuration, and documentation. Note established conventions and where they differ across clients, shells, or platforms.
4. Apply `technical-research` before every external technology lookup. Verify the version used by the repository before relying on external behavior.
5. Report file paths and symbols as evidence. Separate confirmed behavior, inference, and unresolved questions.

Before concluding, inspect matching files in context and account for relevant callers, tests, configuration, and documentation. For absence claims, check search scope, ignored files, and truncation; an empty or partial result is not proof of absence.

Return relevant paths and symbols, affected areas, and unknowns. Scale investigation to the question without skipping the gate. Continue authorized implementation once its research questions are answered.
