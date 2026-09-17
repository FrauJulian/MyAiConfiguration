#!/usr/bin/env python3
"""Validate the generated configuration formats without third-party packages."""

from __future__ import annotations

import json
import sys
import tomllib
from pathlib import Path


CLAUDE_TOP_LEVEL = {"permissions", "sandbox", "env", "statusLine", "hooks"}
CLAUDE_PERMISSION_KEYS = {"defaultMode", "allow", "deny"}
CLAUDE_SANDBOX_KEYS = {"enabled", "allowUnsandboxedCommands"}
CLAUDE_STATUS_LINE_KEYS = {"type", "command"}
CLAUDE_HOOK_KEYS = {"type", "command", "timeout"}
CLAUDE_PERMISSION_MODES = {"acceptEdits", "auto", "bypassPermissions", "default", "dontAsk", "plan"}


def fail(message: str) -> None:
    raise ValueError(message)


def require_keys(value: object, allowed: set[str], label: str) -> dict[str, object]:
    if not isinstance(value, dict):
        fail(f"{label} must be an object")
    unknown = set(value) - allowed
    if unknown:
        fail(f"{label} has unknown keys: {', '.join(sorted(unknown))}")
    return value


def validate_claude(path: Path) -> None:
    settings = require_keys(json.loads(path.read_text(encoding="utf-8-sig")), CLAUDE_TOP_LEVEL, str(path))
    permissions = require_keys(settings.get("permissions"), CLAUDE_PERMISSION_KEYS, "permissions")
    if permissions.get("defaultMode") not in CLAUDE_PERMISSION_MODES:
        fail("permissions.defaultMode is unsupported")
    for key in ("allow", "deny"):
        if not isinstance(permissions.get(key), list) or not all(isinstance(item, str) for item in permissions[key]):
            fail(f"permissions.{key} must be an array of strings")
    sandbox = require_keys(settings.get("sandbox"), CLAUDE_SANDBOX_KEYS, "sandbox")
    if sandbox.get("enabled") is not True or sandbox.get("allowUnsandboxedCommands") is not False:
        fail("sandbox must be enabled without unsandboxed command retries")
    env = settings.get("env")
    if not isinstance(env, dict) or not all(isinstance(key, str) and isinstance(value, str) for key, value in env.items()):
        fail("env must be an object of string values")
    status_line = require_keys(settings.get("statusLine"), CLAUDE_STATUS_LINE_KEYS, "statusLine")
    if status_line.get("type") != "command" or not isinstance(status_line.get("command"), str):
        fail("statusLine must be a command")
    hooks = settings.get("hooks")
    if not isinstance(hooks, dict):
        fail("hooks must be an object")
    for event, matchers in hooks.items():
        if not isinstance(event, str) or not isinstance(matchers, list):
            fail("hooks must map event names to arrays")
        for matcher in matchers:
            if not isinstance(matcher, dict) or not isinstance(matcher.get("hooks"), list):
                fail(f"hooks.{event} must contain hook arrays")
            for hook in matcher["hooks"]:
                hook = require_keys(hook, CLAUDE_HOOK_KEYS, f"hooks.{event}")
                if hook.get("type") != "command" or not isinstance(hook.get("command"), str) or not isinstance(hook.get("timeout"), int):
                    fail(f"hooks.{event} contains an unsupported command hook")


def validate_rule_skills(package: Path) -> None:
    for path in (package / "skills" / "rules").glob("*/SKILL.md"):
        lines = path.read_text(encoding="utf-8-sig").splitlines()
        if len(lines) < 4 or lines[0] != "---" or lines[3] != "---" or not lines[1].startswith("name: ") or not lines[2].startswith("description: "):
            fail(f"{path}: invalid generated skill frontmatter")
        description = json.loads(lines[2].removeprefix("description: "))
        if not isinstance(description, str) or not description.strip():
            fail(f"{path}: skill description must be a quoted, nonempty string")


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: validate-config.py <codex-toml> <claude-json>", file=sys.stderr)
        return 2
    tomllib.loads(Path(sys.argv[1]).read_text(encoding="utf-8-sig"))
    validate_claude(Path(sys.argv[2]))
    validate_rule_skills(Path(sys.argv[2]).parent)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, json.JSONDecodeError, tomllib.TOMLDecodeError) as error:
        print(f"configuration validation failed: {error}", file=sys.stderr)
        raise SystemExit(1)
