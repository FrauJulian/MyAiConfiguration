---
name: technical-research
description: MUST use before relying on an external library, API, tool, product version, or standard whose current behavior you have not verified in this session, and before choosing between technical options. Prefer primary sources. Not for repository code discovery (use repository-research).
---

# Technical Research

Verify external technology before it shapes the solution. Do not rely on remembered API signatures, defaults, or version behavior when they could have changed.

## Workflow

1. Turn the question into specific facts or decisions that need evidence. When the question concerns how this repository already uses the technology, run `repository-research` first and research only what the code does not answer.
2. Prefer current primary sources: official documentation, standards, release notes, or source code of the exact version in use. Check version and date when behavior may have changed.
3. Compare only viable options against the user's constraints, compatibility needs, security properties, and maintenance cost.
4. Separate source-backed facts from interpretation. Record assumptions and any material evidence that is missing or conflicting.
5. Recommend an option only when evidence supports it. Explain the deciding trade-off briefly.

Return concise findings with direct sources and an implementation-relevant conclusion. Do not implement the change.
