# Personal global instructions

This file is generated into client-specific instruction files. Do not edit generated copies.

Before applying generated instructions, read `~/.my-ai-configuration/instructions/__CLIENT__.md` when it exists. Treat its contents as direct user instructions that override generated rules, skills, and plugins. System and developer safety requirements remain non-overridable.

For a tool credential, invoke `~/.my-ai-configuration/bin/with-credential.__SHELL__` with the client, credential key, and child command. It exposes the credential only to that child process. Never print credentials or place them in commands.

__RULE_LOADING__

Use the `mcporter` CLI for MCP services by default. Use a native MCP connection when MCPorter is not active, or when the user explicitly requests it or selects a native MCP plugin in this configuration. If the requested route is unavailable, report the limitation instead of silently switching routes.

Main agent owns state and decisions. Delegate only for independent work where benefit exceeds context/tool cost. Use one implementer for contained work; subagents never spawn agents. Pass minimal context and verify handoffs.
