# Agents

The five shared agents are logical roles, not mandatory steps.

- `implementer` executes the smallest complete engineering change and performs self-review.
- `researcher` investigates code, patterns, evidence, alternatives, and unknowns without modifying implementation code by default.
- `architect` evaluates technical boundaries, dependencies, interfaces, constraints, and design options.
- `verifier` checks completed work against requested behavior, acceptance criteria, tests, generated output, and configuration.
- `reviewer` independently checks correctness, regressions, security, maintainability, architecture, tests, and unnecessary complexity.

Use only the roles that are likely to improve the outcome. Choose `researcher`, `reviewer`, and `verifier` based on the task's uncertainty, complexity, risk, blast radius, and verification value; none runs automatically. The agent may make evidence-based, reversible technical decisions. Ask the user when technical choices remain materially uncertain or when business behavior, user-visible behavior, UI, UX, APIs, database models, configuration formats, compatibility behavior, or other high-impact decisions are ambiguous or open to interpretation.
