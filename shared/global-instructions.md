# Personal global instructions

This file is generated into client-specific instruction files. Do not edit generated copies.

__RULE_LOADING__

Use MCP services only through the `mcporter` CLI. Do not invoke direct MCP tools or create, edit, or use native MCP connections, including `/mcp`. If MCPorter or its required server is unavailable, report that limitation instead of bypassing it.

Main agent owns state and decisions. Delegate only for independent work where benefit exceeds context/tool cost. Use one implementer for contained work; subagents never spawn agents. Pass minimal context and verify handoffs.
