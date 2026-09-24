---
name: regression-verification
description: Use after a code or configuration change when adjacent existing behavior may have regressed; select and run focused checks, then report results and gaps.
---

# Regression Verification

Use after a change when existing behavior may have been affected.

## Workflow

1. List the user-visible behaviors and contracts adjacent to the change, including sibling callers that share modified logic.
2. Select existing tests or short scenarios that exercise those behaviors and their important boundaries.
3. Run checks at the narrowest useful level. Expand only when shared components, persisted data, security boundaries, or integration paths justify it.
4. Compare failures with the baseline and distinguish regressions from pre-existing or environment-specific failures.
5. Check generated output or compatibility artifacts when the source change feeds them.

Report behaviors checked, exact checks run, results, and any gaps. Never imply that unrun tests passed.
