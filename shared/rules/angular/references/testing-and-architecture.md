## Testing

* Test behavior, not implementation details.
* Prefer focused component tests.
* Test critical user interactions.
* Test services and domain logic independently where useful.
* Avoid brittle tests coupled to internal structure.
* Avoid excessive mocking.
* Mock external boundaries rather than internal implementation details.
* Keep tests deterministic.
* Avoid time-dependent tests without controlled clocks.
* Avoid network-dependent tests without proper isolation.
* Keep test setup minimal and readable.
* Update tests when refactoring changes structure but not behavior.

## Architecture

* Keep UI, application, domain and data-access concerns separated where practical.
* Organize code by feature rather than by technical file type when it improves cohesion.
* Avoid circular dependencies.
* Avoid cross-feature imports without a clear contract.
* Keep shared code genuinely shared.
* Do not move feature-specific logic into generic shared modules.
* Avoid dumping unrelated helpers into global utility files.
* Keep public APIs of feature areas small.
* Avoid exposing internal implementation details across feature boundaries.
* Prefer local ownership of state and logic.

## Code Quality

* Use strict TypeScript settings.
* Avoid `any`.
* Avoid unnecessary type assertions.
* Avoid non-null assertions unless safety is guaranteed.
* Prefer modern, readable syntax.
* Use descriptive names.
* Avoid vague names such as `data`, `item`, `value` or `temp` when better names exist.
* Remove dead code.
* Remove unused imports and dependencies.
* Remove commented-out code instead of keeping it in source files.
* Do not add comments unless the user explicitly requests them.
* Treat Angular, TypeScript and lint warnings seriously.
* Do not suppress diagnostics without a concrete reason.
* Prefer correctness, security and maintainability over cleverness.

## Dependency Rules

* Prefer Angular and browser platform capabilities before adding third-party libraries.
* Do not add dependencies without a clear benefit.
* Avoid libraries that duplicate existing framework functionality.
* Avoid abandoned or poorly maintained packages.
* Keep Angular package versions aligned.
* Do not mix incompatible Angular package versions.
* Respect the existing lockfile and package manager.
* Avoid unrelated dependency upgrades.
