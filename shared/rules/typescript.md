# TypeScript Code Guidelines

* Write clear, readable, maintainable code first.
* Prefer modern TypeScript and current ECMAScript syntax.
* Keep code simple and explicit.
* Avoid clever or overly abstract solutions.
* Follow the existing project style and architecture.
* Enable strict TypeScript settings where possible.
* Prefer `strict: true`.
* Avoid `any`.
* Prefer precise types over broad types.
* Prefer `unknown` over `any` for untrusted or unknown values.
* Narrow types explicitly before use.
* Prefer strongly typed models over loose objects.
* Avoid excessive type assertions.
* Avoid non-null assertions unless safety is guaranteed.
* Prefer discriminated unions for state and variant modeling.
* Prefer literal unions over arbitrary strings.
* Prefer enums only when they provide a clear benefit.
* Prefer `readonly` where mutation is not required.
* Prefer immutable data where practical.
* Avoid unnecessary mutation.
* Avoid global mutable state.
* Keep functions small and focused.
* Keep modules focused on a clear responsibility.
* Prefer composition over inheritance.
* Avoid unnecessary classes when functions and plain objects are sufficient.
* Avoid unnecessary interfaces and abstractions.
* Prefer concrete object types when no abstraction is required.
* Use interfaces primarily when extension, implementation contracts, or declaration merging is actually useful.
* Prefer `type` aliases for unions, compositions, mapped types, and local data models.
* Avoid unnecessary wrapper types.
* Avoid excessive generic complexity.
* Keep generic constraints explicit and meaningful.
* Avoid deeply nested conditional or mapped types unless they provide clear value.
* Prefer readable types over type-system cleverness.
* Avoid duplicated type definitions.
* Derive types from existing sources when practical.
* Do not duplicate backend contracts manually when generated or shared types are available.
* Prefer explicit return types for public APIs and non-trivial functions.
* Prefer inference for simple local variables.
* Avoid unnecessary annotations when inference is obvious.
* Prefer `const` by default.
* Use `let` only when reassignment is required.
* Avoid `var`.
* Prefer optional chaining and nullish coalescing where appropriate.
* Do not use `||` when `0`, `false`, or empty strings are valid values.
* Handle `null` and `undefined` intentionally.
* Avoid mixing `null` and `undefined` without a clear convention.
* Prefer early returns over excessive nesting.
* Avoid deeply nested control flow.
* Avoid overly large functions.
* Avoid hidden side effects.
* Keep pure logic pure where practical.
* Prefer deterministic behavior.
* Avoid implicit runtime coercion.
* Use strict equality.
* Avoid unnecessary object spreading in hot paths.
* Avoid unnecessary array copies.
* Avoid unnecessary intermediate arrays.
* Avoid repeated `.map()`, `.filter()`, or `.reduce()` chains in performance-critical paths.
* Use array methods when they improve readability and performance is not critical.
* Prefer appropriate data structures such as `Map` and `Set` when lookup behavior requires them.
* Avoid O(n²) patterns when a better structure is practical.
* Measure performance before micro-optimizing.
* Avoid unnecessary JSON serialization and parsing.
* Avoid unnecessary deep cloning.
* Avoid `JSON.parse(JSON.stringify(...))` as a cloning strategy.
* Prefer platform APIs such as `structuredClone` when deep cloning is actually required.
* Avoid synchronous blocking operations in server-side hot paths.
* Prefer asynchronous APIs for I/O.
* Always handle rejected promises.
* Avoid floating promises.
* Use `await` when sequencing is required.
* Use `Promise.all` for independent operations when safe.
* Limit concurrency for large workloads.
* Avoid uncontrolled `Promise.all` over very large collections.
* Support cancellation with `AbortSignal` where applicable.
* Clean up event listeners, timers, subscriptions, streams, and resources.
* Avoid memory leaks caused by retained closures or listeners.
* Do not swallow exceptions.
* Preserve useful error context.
* Use typed domain errors where they improve handling.
* Avoid exceptions for normal control flow.
* Validate external input at system boundaries.
* Never trust API payloads, query parameters, environment variables, storage data, or user input based solely on TypeScript types.
* Use runtime validation for untrusted external data.
* Do not assume compile-time types provide runtime safety.
* Prefer schema validation when external contracts are complex.
* Never expose secrets, tokens, credentials, or sensitive data.
* Do not log sensitive information.
* Avoid unsafe dynamic property access.
* Avoid `eval`, `Function`, and dynamic code execution.
* Avoid unsafe HTML injection.
* Sanitize untrusted HTML when rendering HTML is required.
* Avoid weakening TLS, authentication, authorization, CSP, validation, or other security controls.
* Treat all external data as untrusted.
* Prefer secure defaults.
* Do not disable security checks for convenience.
* Avoid prototype pollution risks when merging untrusted objects.
* Prefer allowlists over denylists for security-sensitive validation.
* Keep dependencies minimal.
* Prefer built-in platform APIs over adding small utility dependencies.
* Do not add dependencies without a clear reason.
* Avoid abandoned or unnecessary packages.
* Keep dependencies current and supported.
* Respect lockfiles.
* Do not manually modify generated lockfile content.
* Avoid broad dependency upgrades unrelated to the task.
* Use ESM or the project's existing module system consistently.
* Avoid mixing module systems without necessity.
* Prefer named exports unless the project convention favors default exports.
* Keep import paths consistent.
* Remove unused imports and exports.
* Avoid circular dependencies.
* Keep frontend, domain, application, and infrastructure concerns separated where applicable.
* Keep API and transport models separate from domain logic when necessary.
* Do not leak implementation details through public APIs.
* Avoid unnecessary public exports.
* Keep module boundaries intentional.
* Write code that is easy to test.
* Prefer behavior-based tests.
* Avoid tests coupled to implementation details.
* Mock only external boundaries or expensive dependencies where practical.
* Keep tests deterministic.
* Avoid time-, network-, and environment-dependent tests without proper isolation.
* Remove dead code instead of keeping it as commented-out code.
* Do not add comments unless the user explicitly requests them.
* Use descriptive naming.
* Avoid vague names such as `data`, `obj`, `item`, `temp`, or `value` when more precise names are available.
* Avoid abbreviations unless they are established domain terminology.
* Keep naming conventions consistent.
* Treat lint and TypeScript errors seriously.
* Do not suppress ESLint or TypeScript diagnostics without a concrete reason.
* Avoid `@ts-ignore`.
* Prefer `@ts-expect-error` only when the error is intentional and documented.
* Do not disable lint rules globally for local problems.
* Prefer correctness, security, maintainability, and predictable behavior over micro-optimizations.

## Performance Priority

Prioritize performance work in this order:

* Architecture
* Network and API usage
* Database access
* Algorithms and data structures
* Rendering and state updates
* Concurrency
* Memory allocations
* CPU micro-optimizations

Never optimize based purely on assumptions.

## Safety Rule

* Compile-time type safety is not runtime validation.
* Validate all external and untrusted data.
* Do not use `any`, type assertions, non-null assertions, or disabled compiler checks to bypass real type problems.
* Prefer making invalid states unrepresentable where practical.
