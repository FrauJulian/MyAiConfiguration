# Agent coordination

## Ownership and context

The main agent owns the goal, decisions, shared knowledge, and progress. Subagents report to their parent; the parent routes only relevant conclusions, file/symbol references, unresolved risks, and constraints. Direct peer communication needs a concrete dependency and parent coordination; never create a communication mesh or let subagents spawn agents.

Delegate only when correctness, specialization, independence, or parallelism outweighs duplicated context and tool cost. Do cheap exploration directly. Use one implementer for contained work. Parallel roles need independent scopes and materially different value; reviewer plus verifier is not an automatic pair.

Each assignment contains only: concrete task, allowed scope/ownership, success criteria, a few starting references, and the handoff protocol reference. Include relevant constraints and tell workers about concurrent edits. Disable conversation inheritance when supported (for example, choose a fresh context); otherwise keep the explicit prompt minimal and do not claim isolation the client cannot provide. Never preload full conversations, repository summaries, architecture, unrelated files, or earlier agent outputs.

Start at supplied references. Retrieve additional symbols, callers, tests, configuration, or applicable rules only to resolve a concrete question. Reuse reliable findings; reread when code changed or evidence is insufficient. Return unresolved business decisions to the main agent.

## Handoff

Use these headings; omit empty optional sections:

```text
RESULT
One concise conclusion.
EVIDENCE
Concrete file:symbol references, commands and outcomes, tests, or sources.
CHANGES
Changed files, if any.
RISKS
Only unresolved risks, uncertainty, or assumptions.
NEXT
Only work still required.
```

Do not repeat the assignment or repository background. Reference code instead of copying it; quote exact code only when needed to explain a defect. Separate conclusions from evidence and confirmed facts from uncertainty. Identify execution versus inspection; never imply an unrun check passed. Include severity and actionable location for review findings.

## Review and verification

Reviewer: analytical correctness, regressions, architecture, maintainability, security, and contracts. Start with the actual diff and changed symbols, then necessary direct callers/dependencies and tests. Expand only when correctness depends on interfaces, shared state, configuration, persistence, security boundaries, generated code, or external/public contracts. Never default to full-repository exploration or rerunning the entire test suite.

Verifier: execution evidence against acceptance criteria. Choose relevant tests, builds, checks, generated-output validation, or reproduction steps; do not repeat an architecture review unless execution exposes a design issue. Reuse adequate earlier evidence. Both roles follow proportional verification; neither is mandatory for every change.

## Canonical task state

For long-running work, the main agent maintains one compact state with `goal`, `decisions`, `changed`, `verified`, `open`, and `risks`. Store conclusions and file/symbol references, never transcripts, copied source, secrets, or narration. Update after material decisions, changes, and verification, before compaction when possible. Mark stale evidence after relevant edits.

Use an existing task-state facility when available; otherwise use the workspace's `.ai-session/state.json`. Keep one active owner per workspace; use separate checkouts for concurrent unrelated tasks. Runtime state is local, not committed. Explicitly share its location when needed; subagents may read it but return updates to the parent instead of maintaining copies. Do not paste the full state into every assignment.

On recovery, verify that the state matches the current workspace and goal, then inspect only unresolved work and changed evidence. Session hooks point to an existing workspace file; they never author decisions or infer completed verification. A pointer is not proof that state is current. Codex follows the same recovery rule manually where lifecycle hooks are unavailable.
