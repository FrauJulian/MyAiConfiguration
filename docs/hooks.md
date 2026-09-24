# Hooks

Hook scripts and optional utilities live in `shared/hooks/scripts/`. The flashbang entry points live directly in `shared/hooks/`. Shipping a script does not automatically register it as a hook.

The adapters register these events:

| Client | Event | Action |
| --- | --- | --- |
| Codex and Claude | `Stop` | Run the finish notification (`flashbang`). |
| Claude | `PreCompact` | Record the compaction timestamp under the installed configuration root and point to existing workspace task state. |
| Claude | `SessionStart` | Print an absolute pointer if the workspace's `.ai-session/state.json` exists. |

The main agent alone maintains canonical task state. Hooks never write or summarize it, print its contents, or infer completed verification. They use the hook event's `cwd`, falling back to the process working directory when no workspace is supplied. Malformed event data does not fall back to another project. An absent state file is a successful no-op. Legacy state under the installed configuration root is not automatically adopted; confirm its task before migrating it. The scripts do not grant permissions, bypass approvals, or replace client permission systems.

When enabled during installation or update, Flashbang runs on `Stop`, after the main agent finishes responding. The default flash lasts about 500 milliseconds. The PowerShell command omits `-WindowStyle Hidden`, which can hide or minimize the shared terminal. The PowerShell hook creates a low-opacity click-through overlay without activating another window when its native GUI APIs are available; unsupported runtimes exit safely. The Bash hook uses Python's `tkinter`, uses `xrandr` for multi-monitor bounds when available, and falls back to `notify-send` when the overlay is unavailable. Registered hooks are best effort: errors do not fail a Claude session.

`Validate-CommandSafety`/`validate-command-safety.sh` and `Invoke-PostChangeVerification`/`invoke-post-change-verification.sh` are unregistered utilities. The safety utilities check command text for selected dangerous patterns; the PowerShell variant also checks some absolute paths. Neither is a complete security boundary. The verification utilities explicitly run the repository build when invoked; they are not an automatic requirement after each change.

`Test-SessionConfig`/`test-session-config.sh` checks required repository inputs and is called by the build. Build and doctor do not execute the registered notification or session-state hooks. Claude's status line is a separate `statusLine` command, not a hook event.
