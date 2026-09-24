---
name: review-pull-request
description: Use when reviewing a pull request or proposed diff for actionable defects, compatibility problems, security risks, and merge readiness. Do not implement review feedback.
---

# Review Pull Request

Review requested pull requests or proposed diffs for correctness, compatibility, and merge risk.

## Workflow

1. Identify the target branch and exact diff. Read the relevant surrounding code, callers, tests, and configuration before judging a change.
2. Trace changed behavior through its entry points and consumers. Check error paths, boundary conditions, data handling, and security-sensitive flows when affected.
3. Compare the implementation with the stated requirement and established repository patterns. Distinguish a concrete defect from a preference or speculative concern.
4. Check compatibility of public APIs, file formats, migrations, configuration, and generated output where relevant.
5. Inspect available verification evidence. Run checks only when the review request and environment call for them; report unrun checks accurately.

## Findings

List actionable findings first, ordered by severity. For each, give the location, the triggering condition, the user or system impact, and a practical correction. Do not report issues already fixed in the diff. If no concrete finding remains, say so and note meaningful verification gaps.

Do not modify the reviewed change unless asked to implement the feedback.
