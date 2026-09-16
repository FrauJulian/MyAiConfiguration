# Hooks

This directory contains registered hooks and optional utilities. They do not bypass client permission prompts or grant access.

Both clients register `Stop` (`flashbang`) for finish notifications. Claude also registers `PreCompact` (`Record-Compact`/`record-compact.sh`) and `SessionStart` (`Show-SessionStatePointer`/`show-session-state-pointer.sh`). These use `.ai-session/` under the installed configuration root: the first records a compaction timestamp, and the second points to an existing `state.json`. They do not create a task summary.

`Validate-CommandSafety`/`validate-command-safety.sh` and `Invoke-PostChangeVerification`/`invoke-post-change-verification.sh` are not registered or invoked automatically. The safety utility checks selected command-text patterns; the verification utility runs the repository build only when explicitly invoked. `Test-SessionConfig`/`test-session-config.sh` checks repository inputs during a build.
