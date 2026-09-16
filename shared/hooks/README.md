# Hooks

This directory contains registered hooks and optional utilities. They do not bypass client permission prompts or grant access.

Both clients register `Stop` (`flashbang`) for finish notifications. Claude also registers `PreCompact` (`Record-Compact`/`record-compact.sh`) and `SessionStart` (`Show-SessionStatePointer`/`show-session-state-pointer.sh`). PreCompact records its timestamp under the installed configuration root. Both session hooks point to an existing workspace `.ai-session/state.json`, using event `cwd` or the process working directory. The main agent owns that state; hooks never write it or print its contents. Missing state is a successful no-op.

`Validate-CommandSafety`/`validate-command-safety.sh` and `Invoke-PostChangeVerification`/`invoke-post-change-verification.sh` are not registered or invoked automatically. The safety utility checks selected command-text patterns; the verification utility runs the repository build only when explicitly invoked. `Test-SessionConfig`/`test-session-config.sh` checks repository inputs during a build.
