# Hooks

Hook scripts and optional utilities live in `shared/hooks/scripts/`. The flashbang entry points live directly in `shared/hooks/`. Shipping a script does not automatically register it as a hook.

The adapters register these events:

| Client | Event | Action |
| --- | --- | --- |
| Codex and Claude | `Stop` | Run the finish notification (`flashbang`). |
| Claude | `PreCompact` | Append an event and UTC timestamp to `.ai-session/telemetry.jsonl` under the installed configuration root. |
| Claude | `SessionStart` | Print a short pointer if `.ai-session/state.json` exists under that root. |

The session-state hooks do not create a task summary or restore conversation state. Their paths are relative to the installed configuration root, not the current project. The scripts do not grant permissions, bypass approvals, or replace client permission systems.

The flashbang runs on `Stop`, after the main agent finishes responding. The default flash lasts about 500 milliseconds. The Windows command omits `-WindowStyle Hidden`, which can hide or minimize the shared terminal. The PowerShell hook creates a low-opacity click-through overlay without activating another window. The Bash hook uses Python's `tkinter`, uses `xrandr` for multi-monitor bounds when available, and falls back to `notify-send` when the overlay is unavailable.

`Validate-CommandSafety`/`validate-command-safety.sh` and `Invoke-PostChangeVerification`/`invoke-post-change-verification.sh` are unregistered utilities. The former checks command text for selected dangerous patterns and outside-workspace paths; it is not a complete security boundary. The latter explicitly runs the repository build when invoked; it is not an automatic requirement after each change.

`Test-SessionConfig`/`test-session-config.sh` checks required repository inputs and is called by the build. Build and doctor do not execute the registered notification or session-state hooks. Claude's status line is a separate `statusLine` command, not a hook event.
