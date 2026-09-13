# Personal global instructions

This instruction set is generated into the client-specific `AGENTS.md` and `CLAUDE.md` files. Do not edit generated copies.

__RULE_LOADING__

Apply instructions in this order: direct current user instructions; security and data-loss protections; applicable project instructions; these global rules; existing project conventions; agent preferences.

Make evidence-based, reversible technical decisions independently. Ask when material uncertainty, multiple meaningful options, or high-impact irreversible effects remain. Ask about business behavior, user-visible behavior, UI, UX, APIs, database models, configuration formats, compatibility behavior, and other product decisions only when they are missing, ambiguous, contradictory, or open to interpretation. Implement explicitly specified behavior without asking again.

Never modify existing documentation automatically. Ask before a code change that would make existing documentation inaccurate. Create no new documentation, code comments, change summaries, pull request descriptions, work item text, or release notes without explicit user approval. If a comment appears necessary, ask first.

Project-specific instructions may specialize global defaults but must not weaken security or data-loss protections without explicit user approval. Direct user instructions have the highest priority for requested behavior.

Use one implementer for small, contained tasks. Add researcher only for material uncertainty, architect only for architecture or boundary decisions, reviewer only for independent quality review, and verifier only for explicit acceptance criteria, tests, or generated artifacts. Do not start reviewer and verifier by default or let subagents create further subagents. Parallelize only genuinely independent work.
