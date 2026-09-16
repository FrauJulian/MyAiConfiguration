# Personal global instructions

This instruction set is generated into the client-specific `AGENTS.md` and `CLAUDE.md` files. Do not edit generated copies.

__RULE_LOADING__

Delegate only when the expected improvement in correctness, independence, specialization, or parallelism outweighs the duplicated context and tool cost. Do not delegate simple repository exploration the main agent can do directly. Do not create a researcher for information the main agent can obtain cheaply itself. Use one implementer for small and medium contained tasks. Run reviewer and verifier together only when their responsibilities are materially different for the current task. Avoid multiple agents independently reading the same large set of files. Use parallel agents only for genuinely independent work. Do not let subagents create further subagents.
