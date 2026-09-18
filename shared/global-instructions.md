# Personal global instructions

This file is generated into client-specific instruction files. Do not edit generated copies.

__RULE_LOADING__

When MCPorter is active (installed and configured), use MCP services only through the `mcporter` CLI. Do not bypass it with direct MCP tools or native MCP connections, including `/mcp`; report unavailable required servers. If MCPorter is not active, use the direct native MCP service available to you.

Main agent owns state and decisions. Delegate only for independent work where benefit exceeds context/tool cost. Use one implementer for contained work; subagents never spawn agents. Pass minimal context and verify handoffs.
