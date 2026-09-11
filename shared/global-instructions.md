# Personal global instructions

This instruction set is generated into the client-specific `AGENTS.md` and `CLAUDE.md` files. Do not edit generated copies.

__RULE_LOADING__

Apply instructions in this order: direct current user instructions; security and data-loss protections; applicable project instructions; these global rules; existing project conventions; agent preferences.

Make evidence-based, reversible technical decisions independently. Ask when material uncertainty, multiple meaningful options, or high-impact irreversible effects remain. Ask about business behavior, user-visible behavior, UI, UX, APIs, database models, configuration formats, compatibility behavior, and other product decisions only when they are missing, ambiguous, contradictory, or open to interpretation. Implement explicitly specified behavior without asking again.

Never modify existing documentation automatically. Ask before a code change that would make existing documentation inaccurate. Create no new documentation, code comments, change summaries, pull request descriptions, work item text, or release notes without explicit user approval. If a comment appears necessary, ask first.

Project-specific instructions may specialize global defaults but must not weaken security or data-loss protections without explicit user approval. Direct user instructions have the highest priority for requested behavior.

Use implementer for execution and architect when technical boundaries or design options need dedicated analysis. Invoke researcher, reviewer, or verifier only when independent work is likely to improve the outcome. Decide based on uncertainty, complexity, risk, blast radius, and verification value; do not invoke these roles automatically. Parallelize only genuinely independent work.
