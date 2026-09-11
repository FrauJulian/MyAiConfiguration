# C# Code Guidelines

* Write clear, readable, maintainable code first.
* Optimize only based on measurements and profiling.
* Prefer simple solutions over clever abstractions.
* Follow current C# and .NET conventions.
* Prefer immutable data where practical.
* Keep methods small and focused.
* Keep classes focused on a single responsibility.
* Avoid unnecessary inheritance.
* Prefer composition over inheritance.
* Use `sealed` when inheritance is not intended.
* Avoid unnecessary abstractions and wrapper layers.
* Avoid premature generalization.
* Prefer explicit code over hidden magic.
* Avoid unnecessary reflection.
* Avoid unnecessary runtime type checks.
* Avoid unnecessary allocations in hot paths.
* Avoid unnecessary collection copies.
* Avoid unnecessary string allocations.
* Avoid unnecessary LINQ in performance-critical paths.
* Use LINQ where it improves readability and performance is irrelevant.
* Choose collections based on access patterns.
* Preallocate collection capacity when the expected size is known.
* Avoid large mutable structs.
* Use `Span<T>` and related APIs only when they provide a measurable benefit.
* Prefer `Task` over `ValueTask` unless `ValueTask` is justified by profiling.
* Use async only for genuinely asynchronous operations.
* Keep async code async throughout the call chain.
* Avoid `.Result`, `.Wait()` and synchronous blocking of async operations.
* Propagate `CancellationToken` through asynchronous APIs.
* Do not create unnecessary background tasks.
* Limit concurrency when processing large workloads.
* Avoid uncontrolled `Task.WhenAll` over large collections.
* Avoid exceptions for normal control flow.
* Fail fast on invalid arguments and invalid state.
* Avoid swallowing exceptions.
* Preserve meaningful exception context.
* Use dependency injection where dependencies require substitution or lifecycle management.
* Avoid service locator patterns.
* Avoid excessive constructor dependencies.
* Keep application, domain and infrastructure concerns separated.
* Avoid unnecessary cross-layer coupling.
* Prefer explicit dependencies.
* Minimize global and static mutable state.
* Design APIs with clear contracts.
* Prefer strongly typed models over loosely typed dictionaries or dynamic objects.
* Validate input at system boundaries.
* Avoid duplicate validation deep inside trusted internal code.
* Treat external input as untrusted.
* Do not expose internal implementation details through public APIs.
* Avoid leaking sensitive information through logs or exceptions.
* Use structured logging.
* Avoid excessive logging in hot paths.
* Avoid logging sensitive data.
* Prefer database-side filtering, projection and aggregation.
* Do not load data that is not needed.
* Avoid N+1 database queries.
* Use no-tracking queries for read-only EF Core operations where appropriate.
* Keep database round trips minimal.
* Avoid unnecessary serialization and deserialization.
* Reuse expensive resources such as HTTP clients and database infrastructure correctly.
* Do not optimize micro-level CPU operations before fixing architectural, database or I/O bottlenecks.
* Prefer algorithms and data structures with appropriate complexity.
* Measure allocations, GC pressure, CPU usage and latency when investigating performance.
* Write code that is easy to test.
* Avoid tests coupled to implementation details.
* Prefer deterministic behavior.
* Avoid hidden side effects.
* Keep naming consistent and descriptive.
* Avoid abbreviations unless they are established domain terminology.
* Remove dead code instead of keeping it as commented-out code.
* Do not add comments or API documentation unless the user explicitly requests them.
* Follow existing project conventions unless there is a strong reason to change them.
* Do not introduce new libraries when the BCL or existing dependencies already solve the problem adequately.
* Prefer fewer dependencies.
* Keep dependency versions current and supported.
* Treat warnings seriously.
* Do not suppress analyzers without a concrete reason.
* Keep performance improvements readable unless the hot path clearly justifies additional complexity.
* Prefer correctness, maintainability and predictable behavior over theoretical micro-optimizations.

## C# Style & Safety

* Prefer modern, readable C# syntax and current .NET conventions.
* Prefer simple, explicit code over outdated or unnecessarily verbose patterns.
* Prefer concrete collection types for parameters, properties and local APIs when no abstraction is required.
* Avoid interface collection types such as `IDictionary<TKey, TValue>`, `IList<T>` or `ICollection<T>` unless polymorphism or API abstraction is actually needed.
* Prefer `Dictionary<TKey, TValue>`, `List<T>`, arrays or other concrete types when the implementation type is known and intentional.
* Prefer strongly typed models over `object`, `dynamic`, loosely typed dictionaries or string-based contracts.
* Validate external input at system boundaries.
* Fail fast on invalid arguments and impossible states.
* Avoid unsafe code unless explicitly required.
* Avoid reflection when a strongly typed solution is practical.
* Avoid hidden side effects and implicit global state.
* Prefer immutable or readonly data where practical.
* Avoid exposing mutable internal collections directly.
* Prefer safe framework APIs over custom low-level implementations.
* Never weaken validation, authorization, certificate checks, encryption or other security controls for convenience.
* Do not log secrets, tokens, credentials or sensitive data.
* Treat all external data as untrusted.
* Prefer correctness and security over minor convenience or micro-optimizations.

## Performance Priority

Prioritize performance work in this order:

* Architecture
* Database access
* Network and I/O
* Algorithms and data structures
* Concurrency
* Allocations and GC pressure
* CPU micro-optimizations

Never optimize based purely on assumptions.
