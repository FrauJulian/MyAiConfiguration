---
name: debugging
description: Use when code, tests, commands, integrations, or user-visible behavior fail unexpectedly; reproduce the failure, trace the cause, and verify a focused fix.
---

# Debugging

Use when a command, test, integration, or user-visible behavior fails or behaves unexpectedly.

## Workflow

1. State expected and observed behavior. Capture the exact error, input, environment, and reproduction steps that matter.
2. Reproduce the failure with the smallest relevant command or scenario. If it cannot be reproduced, inspect logs, recent changes, callers, configuration, and environment differences before changing code.
3. Trace the failing path through its callers and dependencies. Compare a failing case with a successful one and identify the earliest point where behavior diverges.
4. Form a root-cause explanation supported by evidence. If several causes remain plausible, gather the cheapest evidence that distinguishes them.
5. Fix the cause at the narrowest shared boundary that covers affected callers. Preserve unrelated behavior and keep error handling intact.
6. Run the smallest check that would fail if the defect returned, then add broader regression checks when the change affects connected paths or data.

Do not hide the failure with retries, broad exception handling, suppressed diagnostics, or caller-specific guards unless evidence shows that is the actual cause.

## Report

Summarize the cause, evidence, change, checks run, and any remaining uncertainty. Separate environment failures from product failures. Never claim a check passed if it did not run.
