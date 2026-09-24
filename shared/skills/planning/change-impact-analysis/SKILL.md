---
name: change-impact-analysis
description: Use before implementation when a proposed code, configuration, data, or workflow change has uncertain callers, compatibility effects, dependencies, or blast radius. Return an impact analysis without implementing it.
---

# Change Impact Analysis

Use before a change when its consumers, compatibility effects, or blast radius are uncertain.

## Workflow

1. Define the proposed change and the behavior or contract it affects.
2. Locate direct callers, related implementations, shared helpers, configuration, generated output, and relevant tests. Start with exact-path and symbol searches; broaden only when the flow is unclear.
3. Trace likely impact through runtime paths, persisted data, client integrations, deployment, and documentation as applicable.
4. Identify compatibility concerns, failure modes, security or data-loss risks, and dependencies on version or environment.
5. Separate confirmed impacts from assumptions and unknowns. Do not treat a possible downstream effect as a fact without evidence.
6. Recommend proportionate verification tied to the risks found.

Return a concise impact map: affected areas, evidence, risks, unknowns, and checks. Do not implement the proposal unless asked.
