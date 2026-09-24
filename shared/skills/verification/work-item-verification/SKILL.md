---
name: work-item-verification
description: Use when checking whether completed work satisfies explicit scope, constraints, and acceptance criteria; map each criterion to evidence and mark it met, unmet, or unverified.
---

# Work Item Verification

Use when deciding whether a completed change satisfies a defined work item or review request.

## Workflow

1. Read the objective, scope boundaries, acceptance criteria, and material constraints.
2. Map each criterion to direct evidence: changed files, observable behavior, command output, test result, or user-confirmed outcome.
3. Mark each criterion as met, unmet, or unverified. Do not treat a successful build as proof of unrelated behavioral criteria.
4. Confirm the implementation stayed within scope and did not leave generated output, documentation, or consumers inconsistent.
5. Record known limitations, unresolved decisions, and checks that could not run.

Return a criterion-by-criterion result with evidence and a concise completion status. Do not claim completion while a required criterion remains unmet or unverified.
