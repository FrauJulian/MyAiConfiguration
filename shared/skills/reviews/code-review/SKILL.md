---
name: code-review
description: Use for a general review of a code diff when looking for concrete defects, regressions, compatibility issues, and maintainability risks. For focused API, security, performance, UI, WPF, or EF Core reviews, use the matching review skill.
---

# Code Review

Review the requested diff independently for defects and material regression risk.

## Workflow

1. Read the diff and the surrounding code, then identify the behavior and contracts the change intends to affect.
2. Trace callers and data flow through relevant shared helpers. Check normal, boundary, and failure paths rather than reviewing changed lines in isolation.
3. Look for incorrect behavior, compatibility breaks, unsafe input or data handling, resource leaks, concurrency problems, and avoidable complexity where relevant.
4. Check whether the change has focused verification and whether stated results match the evidence. Do not run broad checks by default.
5. Ignore style preferences unless they make the code error-prone or conflict with a repository rule.

## Findings

List only actionable issues, ordered by severity. Include file and line, condition, concrete impact, and the smallest practical fix. Do not modify code unless explicitly asked. If no defect is found, say so and note important unverified risks.
