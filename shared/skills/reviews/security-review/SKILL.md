---
name: security-review
description: Use when asked to assess code or configuration changes for exploitable security weaknesses, trust boundaries, authorization flaws, unsafe input handling, or sensitive-data exposure.
---

# Security Review

Use when asked to review a change for exploitable security weaknesses.

## Review

1. Map inputs crossing a trust boundary and identify the principals, permissions, and resources involved.
2. Trace validation, authentication, authorization, tenant scoping, and output encoding through the actual code path.
3. Check secret handling, filesystem and process access, network destinations, deserialization, dependency sources, and sensitive-data exposure when relevant.
4. Build a plausible attack path: attacker capability, triggering input or state, missing control, and resulting impact.
5. Verify proposed mitigations preserve normal behavior and fail closed where the security boundary requires it.

Report only evidence-backed findings. State severity, preconditions, impact, and a practical fix. Separate confirmed vulnerabilities from defense-in-depth suggestions; do not invent attack scenarios unsupported by the code.
