## Architecture

* Use modern C# and current WPF conventions. Prefer MVVM for non-trivial views and keep code-behind limited to view-specific behavior.
* Keep UI, application, and domain logic separate. Avoid business logic in views and direct service access from controls.
* Keep dependencies explicit and testable; prefer composition over inheritance and avoid unnecessary abstractions or framework wrappers.
* Keep presentation, application, domain and infrastructure concerns separated.
* Avoid direct database access from views or ViewModels.
* Avoid direct HTTP access from controls.
* Keep external integrations behind focused services.
* Avoid circular dependencies.
* Keep feature boundaries clear.
* Do not create shared utility classes for unrelated functionality.
* Keep shared code genuinely reusable.
* Minimize global state.
* Avoid static service access.

## Dependency Injection

* Use dependency injection where lifecycle management, substitution or testability benefits from it.
* Avoid service locator patterns.
* Keep constructor dependencies minimal.
* Do not inject dependencies that are not used.
* Choose service lifetimes intentionally.
* Do not make stateful services global without a concrete reason.
* Avoid introducing interfaces solely for dependency injection when no abstraction is needed.

## Testing

* Keep ViewModels testable without a UI thread where practical.
* Test behavior rather than implementation details.
* Test domain and application logic independently from WPF.
* Avoid brittle tests coupled to XAML structure.
* Keep UI automation tests focused on critical flows.
* Mock external boundaries rather than internal details.
* Keep tests deterministic.
* Avoid real network, database or filesystem dependencies in unit tests unless explicitly intended.

## Code Quality

* Use nullable reference types.
* Prefer modern, readable C# syntax.
* Avoid unnecessary interfaces and abstractions.
* Prefer concrete types where no abstraction is required.
* Use descriptive names.
* Remove dead code.
* Remove commented-out code.
* Do not add comments unless the user explicitly requests them.
* Treat compiler, analyzer and binding warnings seriously.
* Do not suppress warnings without a concrete reason.
* Prefer correctness, responsiveness, security and maintainability over cleverness.

## Performance

* Keep the UI thread responsive.
* Minimize visual tree depth.
* Keep virtualization enabled.
* Avoid unnecessary bindings.
* Avoid unnecessary converters.
* Avoid unnecessary resource lookups.
* Avoid unnecessary property change notifications.
* Avoid frequent full collection refreshes.
* Avoid loading large datasets eagerly.
* Avoid loading large images at full resolution when unnecessary.
* Freeze `Freezable` objects where practical.
* Reuse immutable resources where appropriate.
* Avoid unnecessary animations.
* Avoid high-frequency timers on the UI thread.
* Measure startup time, UI responsiveness, memory usage and rendering performance before micro-optimizing.

## Performance Priority

Prioritize WPF performance work in this order:

* UI architecture
* UI thread blocking
* Data loading and I/O
* Virtualization
* Visual tree complexity
* Binding and notification frequency
* Rendering and images
* Memory retention and leaks
* Allocations
* CPU micro-optimizations

Never optimize based purely on assumptions.
