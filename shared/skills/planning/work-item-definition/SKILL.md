---
name: work-item-definition
description: Use when a request is too vague to scope, estimate, or verify. Define the objective, scope, acceptance criteria, assumptions, dependencies, and only material open questions; do not implement it.
---

# Work Item Definition

Use when a request lacks enough detail to estimate or verify the intended technical outcome.

## Workflow

1. State the user or system outcome in concrete terms.
2. Define what is in scope and what is explicitly out of scope based on the request and current behavior.
3. Write observable acceptance criteria, including relevant failure or edge cases.
4. Record constraints, dependencies, compatibility requirements, and assumptions separately.
5. Ask only questions whose answers would materially change behavior, contracts, permissions, or acceptance. Choose safe reversible defaults for minor implementation details.
6. Identify unresolved risks and a proportionate verification approach.

Return a bounded work item with objective, scope, criteria, assumptions, dependencies, and open questions. Do not invent business rules or start implementation unless asked.
