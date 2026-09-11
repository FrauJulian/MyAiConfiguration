# Refactoring Guidelines

## Core Rule

* Refactor only when it improves readability, maintainability, correctness, performance, safety, or architecture.
* Do not refactor unrelated code without a concrete reason.
* Do not change behavior unless the refactoring explicitly requires it.
* Preserve existing functionality by default.
* Keep refactorings focused and minimal.
* Prefer simple improvements over large rewrites.

## Scope

* Limit changes to the smallest reasonable scope.
* Do not mix unrelated refactorings.
* Do not combine feature work, bug fixes, formatting changes, and broad refactoring unless necessary.
* Avoid repository-wide changes unless explicitly required.
* Do not rename, move, split, or merge files unnecessarily.
* Do not introduce new abstractions without a clear benefit.

## Behavior Preservation

* Existing public behavior must remain unchanged unless explicitly requested.
* Preserve API contracts unless a breaking change is explicitly intended.
* Preserve serialization formats, database contracts, configuration keys, routes, and external integrations unless explicitly required.
* Preserve exception behavior where it is part of an existing contract.
* Preserve thread-safety and concurrency behavior.
* Preserve performance characteristics unless the refactoring intentionally improves them.

## Code Quality

* Prefer modern, readable C# syntax.
* Reduce unnecessary complexity.
* Remove duplication where doing so improves clarity.
* Prefer clear control flow over clever code.
* Reduce nesting where practical.
* Improve naming when current names are misleading or unclear.
* Prefer strongly typed code.
* Avoid unnecessary interfaces and abstractions.
* Avoid unnecessary wrapper classes and indirection.
* Prefer composition over inheritance.
* Remove dead code when it is clearly unused.
* Remove obsolete comments and commented-out code.
* Keep methods and classes focused.

## Architecture

* Respect existing architectural boundaries.
* Do not introduce new layers without a concrete need.
* Avoid circular dependencies.
* Reduce coupling where practical.
* Keep dependencies explicit.
* Do not move business logic into infrastructure or presentation layers.
* Do not weaken encapsulation for convenience.
* Avoid global or static mutable state.

## Performance

* Do not trade significant readability for theoretical micro-optimizations.
* Avoid introducing unnecessary allocations in hot paths.
* Avoid unnecessary collection copies.
* Avoid unnecessary LINQ in performance-critical code.
* Preserve or improve algorithmic complexity.
* Measure performance-sensitive refactorings when relevant.
* Do not assume a refactoring is faster without evidence.

## Safety

* Do not weaken validation, authorization, authentication, encryption, null-safety, or input handling.
* Preserve or improve error handling.
* Preserve cancellation behavior.
* Preserve disposal and resource lifetime semantics.
* Avoid introducing race conditions.
* Avoid exposing mutable internal state.
* Treat external input as untrusted.
* Do not introduce unsafe code unless explicitly required.

## Dependencies

* Do not add new dependencies unless they provide a clear and necessary benefit.
* Prefer existing project dependencies and the .NET BCL.
* Do not replace stable dependencies without a concrete reason.
* Avoid refactorings that increase long-term maintenance cost.

## Tests

* Existing relevant tests must continue to pass.
* Update tests when internal structure changes make it necessary.
* Do not delete valid tests merely because they fail after a refactoring.
* Add tests when the refactoring exposes previously untested critical behavior.
* Prefer behavior-based tests over implementation-detail tests.

## Validation

After a refactoring:

* Build the affected project or solution.
* Run relevant tests.
* Check for new warnings.
* Verify affected code paths.
* Review the diff for accidental behavior changes.
* Check that unrelated files were not modified unnecessarily.
* Confirm that the result is simpler or clearer than before.

## Large Refactorings

* Break large refactorings into small, understandable steps.
* Avoid big-bang rewrites when incremental changes are practical.
* Keep intermediate states buildable where possible.
* Do not perform broad architectural rewrites without explicit user intent.
* If multiple valid architectural directions exist, ask the user before choosing one.

## Decision Rule

* If a refactoring may change externally visible behavior, data contracts, architecture, public APIs, persistence, security, or deployment behavior, ask the user first.
* If the benefit is unclear or the change introduces significant complexity, do not proceed autonomously.
* When uncertain, prefer the smaller and safer refactoring.
