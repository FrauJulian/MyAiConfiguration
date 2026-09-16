# Personal global instructions

This instruction set is generated into the client-specific `AGENTS.md` and `CLAUDE.md` files. Do not edit generated copies.

__RULE_LOADING__

Main agent owns state and decisions. Delegate only when benefit exceeds context/tool cost; do cheap exploration directly. Use one implementer for contained work and independent scopes for parallel work. Avoid duplicated reads. Subagents report to their parent and never spawn agents. Load orchestration guidance for delegation, subagent work, or long-running state; pass minimal context and retrieve more as needed.
