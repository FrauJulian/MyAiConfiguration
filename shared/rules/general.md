# General rules

## Priority

Apply instructions in this order:

1. Direct current user instructions.
2. Non-negotiable security and data-loss protections.
3. Applicable project-specific instructions.
4. These global user-level rules.
5. Existing project conventions.
6. Agent preferences.

Project instructions may specialize global defaults, but must not weaken security or data-loss protections without explicit user approval.

## Decisions

* Make evidence-based, reversible technical decisions independently; ask only when material uncertainty, multiple meaningful options, or high-impact/hard-to-reverse effects remain.
* Ask about business behavior, user-visible behavior, UI, UX, APIs, database models, configuration formats, or compatibility behavior only when it is missing, ambiguous, contradictory, or open to interpretation; implement explicitly specified behavior without asking again.
* For deeper guidance on ambiguous requirements or a meaningful technical choice, consult `decision-rule.md` (Codex: read `rules/decision-rule.md`; Claude: invoke the `rules-decision-rule` skill).

## Semantic repository search

* In Codex and Claude Code, proactively use the `my-ai-qwen3-retrieval` MCP server's `semantic_search` tool whenever available and useful. It always uses Qwen3-Embedding-0.6B for retrieval and Qwen3-Reranker-0.6B for reranking. Discover the tool if it is not already exposed.
* Use semantic search early to find unfamiliar code, understand responsibilities and relationships, locate similar implementations, or investigate behavior described without exact symbols. Reuse relevant results and search again when a new question would benefit.
* Use direct file reads for known paths and exact text search for symbols, literals, and exhaustive caller checks. Combine these with semantic search when meaning-based discovery adds value.
* Treat retrieved passages as leads: verify them against current files in the intended workspace before relying on them. Empty results do not prove absence; stale or unrelated results require direct inspection.
* If retrieval is unavailable, fails, or adds no value, continue with ordinary repository tools. Report failures briefly; avoid repeated failing calls or installing or enabling retrieval without authorization.

* When QMD is available, use its `qmd` MCP tools for questions about indexed Markdown notes, documents, meeting records, or knowledge bases. Verify retrieved results against the source document when the current content matters.

## Verification

* Choose checks independently by behavior, callers, impact, reversibility, and uncertainty. Focused inspection can suffice; builds, tests, new tests, and separate reviews are not automatic.
* Execute the cheapest check that detects the likely failure. Broaden for cross-component effects, security/data-loss risks, failures, or unresolved uncertainty. Small changes can still be risky.
* Add tests for meaningful behavior or plausible regressions, not implementation details or wording. Stop when risks are covered; repeat only when changed evidence warrants it.
* Explicit user/project/CI requirements remain binding. Generic skill mandates for review, builds, tests, or test-first work do not override proportional verification; skipping needless steps needs no permission.
* Report checks and material gaps concisely. Distinguish inspection from execution; never claim unrun checks passed or hide failures.

## Documentation

* Never modify existing documentation automatically.
* Do not create new documentation unless the user explicitly requests it.
* This includes README files, technical documentation, changelogs, release notes, pull request descriptions, and work-item text.
* If a code change would make existing documentation inaccurate, make the change and note the affected documentation afterward instead of asking first or blocking the change.

## Comments

* Do not add new code comments without the user's explicit approval.
* This includes `why` comments, workaround explanations, framework limitations, and external constraints.
* Prefer self-explanatory code and clear names.
* Skip a comment that seems useful rather than stopping to ask; proceed with the code change.

## Tool output

* Prefer a script's documented summary mode for routine agent runs; keep warnings and failure diagnostics visible. Use detailed output when investigating a failure or when requested.

## Language

* Write code and repository-generated user-facing text in English.
