# Hooks

Hooks are conservative entry points shared by clients. They validate obvious command hazards, check repository-local configuration inputs, and provide an optional post-change verification command. They do not bypass client permission prompts or grant access.

Only the `Stop` hook (`flashbang`) is registered in the generated client configuration. `Validate-CommandSafety`/`validate-command-safety.sh` and `Invoke-PostChangeVerification`/`invoke-post-change-verification.sh` are utility scripts, not active hooks; nothing in this repository invokes them automatically. Wire one up as a client-native `PreToolUse`/equivalent hook yourself if you want it enforced, and do not assume it runs otherwise.
