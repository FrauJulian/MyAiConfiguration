---
name: semantic-search
description: MUST apply before EVERY repository search or lookup, including direct reads, exact matches, and follow-up searches. Route known identifiers to direct reads or rg; run semantic retrieval first for unknown identifiers and behavior questions.
---

# Semantic Search

Search the current Git repository, plus the user's registered QMD collections, by meaning. QMD runs locally with Qwen3-Embedding-0.6B, Qwen3-Reranker-0.6B, and QMD Query Expansion 1.7B; a background daemon keeps them loaded.

## Rule

Apply `research`, `repository-research`, and this routing rule before each repository lookup. Known exact identifiers, paths, or strings use direct reads or `rg` under the same research checks. Unknown identifiers require semantic retrieval first; guessed keywords are not known identifiers. Reevaluate the route for every follow-up query. Reuse instructions already in context.

## Run

The same command works in Bash and PowerShell:

    node "$HOME/.my-ai-configuration/qmd/qmd-search.mjs" --query "<full question about behavior>" --top-k 5

Output: JSON list of `{path, line, score, snippet}`, best first. Repository paths are relative to the repository root; hits from other collections are `qmd://<collection>/<path>`.

## Use the results

1. Phrase the query as a full question about behavior, not a keyword list. Batch related questions into one precise query.
2. Open the top hits and verify them against the current files before acting; the index can lag behind uncommitted edits.
3. If no hit is relevant, run one rephrased search before switching to `rg`.
4. Continue with `repository-research` from the verified hits: callers, tests, and conventions.

## Failure

If the command exits non-zero, continue with `rg` and state the limitation in one sentence.
