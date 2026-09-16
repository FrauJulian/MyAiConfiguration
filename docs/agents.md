# Agents

The five shared agents are logical roles, not mandatory steps.

- `implementer` executes the smallest complete engineering change and performs self-review.
- `researcher` investigates code, patterns, evidence, alternatives, and unknowns without modifying implementation code by default.
- `architect` evaluates technical boundaries, dependencies, interfaces, constraints, and design options.
- `verifier` supplies execution evidence from relevant tests, builds, checks, generated output, and behavior reproduction. It does not repeat a general architecture review.
- `reviewer` starts with the actual diff and changed symbols, then examines necessary callers, dependencies, tests, and contracts for analytical correctness. It does not automatically rerun the test suite.

Use only the roles that are likely to improve the outcome. Choose `researcher`, `reviewer`, and `verifier` based on the task's uncertainty, complexity, risk, blast radius, and verification value; none runs automatically. The agent may make evidence-based, reversible technical decisions. Ask the user when technical choices remain materially uncertain or when business behavior, user-visible behavior, UI, UX, APIs, database models, configuration formats, compatibility behavior, or other high-impact decisions are ambiguous or open to interpretation.

## Coordination

The main agent owns task state, decisions, and progress. Subagents report to their parent. The parent forwards only relevant conclusions, references, risks, and constraints; direct peer communication requires a concrete dependency and parent coordination. Subagents cannot create further subagents.

Assignments contain a concrete task, allowed scope and ownership, success criteria, a few starting references, and the handoff protocol reference. Use a fresh subagent context where supported. Do not preload conversations, repository summaries, or full earlier reports. Additional context is retrieved only to answer a concrete question. These are instruction-level policies; client-controlled context inheritance cannot be disabled by this repository where the client exposes no such option.

The shared [orchestration rule](../shared/rules/orchestration.md) defines the `RESULT`, `EVIDENCE`, `CHANGES`, `RISKS`, and optional `NEXT` handoff. Codex loads it as a rule file; Claude loads the generated `rules-orchestration` skill. Agent adapters add only the client-specific loading instruction. The protocol body is not copied into every role or permanent prompt.

## Task state

For long-running work, the main agent maintains one compact state containing `goal`, `decisions`, `changed`, `verified`, `open`, and `risks`. An existing task-state facility is preferred; the file fallback is `.ai-session/state.json` in the current workspace. Subagents may read it when needed, but send updates to the parent. Keep unrelated concurrent tasks in separate checkouts, and keep runtime state out of commits.

The optional `scripts/session-state.ps1` and `scripts/session-state.sh` helpers update this workspace file. Omitted fields are preserved. Their `-Workspace`/`--workspace` option selects the workspace explicitly; the default is the current working directory. Both accept goal, decisions, changed files, completed verification, open items, and risks. `-Pointer`/`--pointer` only prints the existing file's location.

Starting a different goal requires `-Reset -Goal ...` or `--reset --goal ...`, which clears the previous task's decisions and verification. Updates are atomic; legacy field names are migrated when reading existing state.

After compaction, verify that the state belongs to the current goal and workspace before using it. Claude's lifecycle hooks point to an existing workspace state without creating or summarizing it. Codex follows the same recovery instructions manually; no unsupported lifecycle events are registered.
