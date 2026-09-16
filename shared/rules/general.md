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
