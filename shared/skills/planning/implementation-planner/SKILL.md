---
name: implementation-planner
description: Use when requirements are understood but implementation needs multiple dependent steps, affected areas, risk handling, or coordinated verification. Produce a plan without making the changes.
---

# Implementation Planner

Use when an understood change has multiple dependent steps or meaningful coordination risk.

## Workflow

1. Restate the intended outcome and acceptance conditions without expanding the request.
2. Identify the files, components, data contracts, or workflows likely to change. Confirm the repository's existing patterns before proposing new structure.
3. Order work by dependency. Keep steps small enough to review and verify independently where possible.
4. Call out decisions that affect compatibility, data, permissions, or external systems. Resolve routine reversible choices using repository conventions.
5. Pair each substantial step with the cheapest useful verification.
6. Keep the plan concise and omit speculative scaffolding, unrelated cleanup, and work that can safely wait.

Return an actionable sequence with affected areas, risks, and checks. This skill plans only; do not implement the change.
