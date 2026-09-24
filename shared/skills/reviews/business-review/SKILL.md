---
name: business-review
description: Use when assessing whether a product or code change meets stated business requirements and user workflows, including actors, domain rules, acceptance criteria, and unmet cases.
---

# Business Review

Use when reviewing whether a change supports the stated business goal and real user workflows.

## Review

1. Identify the intended actors, goals, and acceptance criteria from the request or product evidence.
2. Trace the affected workflow across its relevant states, permissions, handoffs, and failure paths.
3. Check domain terms, invariants, eligibility rules, and calculations against existing behavior and authoritative product definitions.
4. Look for unmet acceptance criteria, inconsistent outcomes between related workflows, and impacts on existing users or data.
5. Separate stated requirements, observed behavior, assumptions, and recommendations. Ask about material ambiguity rather than inventing business policy.

Report actionable gaps with the affected actor and workflow, evidence, impact, and the requirement or decision needed to resolve them. Do not substitute implementation preference for business intent.
