# TypeScript Coding Style

Apply these rules when changing TypeScript syntax, control flow, or everyday code organization.

* Follow the project's established architecture, formatter, lint rules, and module conventions.
* Prefer `const`; use `let` only when reassignment is needed and avoid `var`.
* Keep functions and modules focused. Prefer early returns and shallow control flow over deeply nested branches or oversized functions.
* Prefer explicit, predictable behavior over implicit coercion, hidden side effects, or overly abstract helpers.
* Use strict equality. Handle `null` and `undefined` intentionally and do not use `||` when `0`, `false`, or an empty string is a valid value.
* Use optional chaining and nullish coalescing where they clarify behavior; avoid mixing nullish conventions without a project reason.
* Keep naming descriptive and consistent. Avoid vague names and abbreviations unless they are established domain terms.
* Remove dead code and unused imports. Do not add comments unless the user asks or a project rule requires them.
