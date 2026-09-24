# TypeScript Testing and Quality

Apply these rules when changing tests, lint configuration, compiler diagnostics, or maintainability checks.

* Prefer behavior-based tests that assert externally observable results. Avoid coupling tests to private implementation details.
* Keep tests deterministic. Control time, randomness, filesystem state, and external services when they affect the result.
* Mock external boundaries or expensive dependencies only when needed; avoid mocks that merely restate implementation details.
* Treat TypeScript, compiler, and lint diagnostics seriously. Do not suppress errors globally or use `@ts-ignore` to hide a real type problem.
* Use `@ts-expect-error` only for an intentional, narrow case whose expected error is part of the test or contract.
* Keep code easy to test through clear module boundaries without adding test-only production exports or hooks without a concrete reason.
* Run focused tests, type checks, and lint for changed paths. Expand checks when shared contracts or generated types are affected.
