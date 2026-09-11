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

## Documentation

* Never modify existing documentation automatically.
* If a code change would make existing documentation inaccurate or outdated, ask the user before changing the code or documentation.
* Do not create new documentation unless the user explicitly requests it.
* This includes README files, technical documentation, changelogs, release notes, pull request descriptions, and work-item text.

## Comments

* Do not add new code comments without the user's explicit approval.
* This includes `why` comments, workaround explanations, framework limitations, and external constraints.
* If a comment appears technically useful or necessary, ask the user before adding it.
* Prefer self-explanatory code and clear names.

## Language

* Write code and repository-generated user-facing text in English.
