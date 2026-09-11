# WPF Code Guidelines

* Use modern C# and current .NET/WPF conventions.
* Keep UI, application logic and domain logic clearly separated.
* Prefer MVVM for non-trivial views.
* Keep code-behind minimal.
* Use code-behind only for view-specific behavior that does not belong in the ViewModel.
* Avoid business logic in views.
* Avoid direct service access from controls.
* Keep dependencies explicit and testable.
* Prefer composition over inheritance.
* Avoid unnecessary abstractions and framework wrappers.
* Follow the existing project architecture unless there is a strong reason to change it.

## MVVM

* Keep ViewModels focused on presentation state and commands.
* Do not put UI element references into ViewModels.
* Do not access `Window`, `UserControl`, `DispatcherObject` or visual tree elements from ViewModels.
* Avoid direct navigation, dialogs or message boxes from ViewModels without an abstraction when testability matters.
* Prefer explicit application services for navigation, dialogs and external interactions.
* Keep domain logic outside ViewModels.
* Do not use ViewModels as general-purpose service containers.
* Keep ViewModel dependencies minimal.
* Prefer immutable or readonly state where practical.
* Avoid duplicated derived state.
* Keep state transitions predictable.

## Data Binding

* Prefer data binding over manual UI synchronization.
* Use strongly typed properties.
* Use appropriate binding modes.
* Prefer `OneWay` when two-way updates are not required.
* Use `TwoWay` only when the UI must modify the source.
* Avoid unnecessary `UpdateSourceTrigger=PropertyChanged` for expensive operations.
* Keep binding paths simple and stable.
* Avoid deeply nested binding paths.
* Do not hide broken bindings.
* Treat binding errors as real defects.
* Use `FallbackValue` and `TargetNullValue` only when they reflect intended behavior.
* Avoid excessive converters.
* Prefer exposing correctly shaped state from the ViewModel over complex converter logic.
* Avoid `MultiBinding` when simpler state modeling is clearer.
* Do not put business logic into converters.

## Property Change Notifications

* Implement property change notifications consistently.
* Avoid raising `PropertyChanged` unnecessarily.
* Raise notifications only when values actually change.
* Keep dependent property notifications explicit.
* Avoid hidden notification chains that are difficult to reason about.
* Prefer reusable base implementations only when they reduce duplication without obscuring behavior.
* Do not use reflection-based notification mechanisms unless there is a concrete benefit.

## Commands

* Prefer commands over click handlers for ViewModel-driven actions.
* Keep command execution focused.
* Avoid putting large workflows directly inside command implementations.
* Keep `CanExecute` logic cheap.
* Refresh command availability only when relevant state changes.
* Avoid command implementations with hidden side effects.
* Handle async commands safely.
* Prevent accidental duplicate execution when an async action must not run concurrently.
* Never use `async void` except for true event handlers.

## Async and Threading

* Keep async operations asynchronous throughout the call chain.
* Avoid `.Result`, `.Wait()` and other synchronous blocking of async work.
* Do not block the UI thread.
* Run I/O asynchronously.
* Move expensive CPU work off the UI thread only when necessary.
* Marshal UI updates back to the UI thread when required.
* Keep Dispatcher usage minimal and explicit.
* Do not use the Dispatcher to hide incorrect threading design.
* Support `CancellationToken` for cancellable long-running operations.
* Cancel obsolete work when views or selections change.
* Prevent race conditions caused by overlapping async operations.
* Handle exceptions from background operations explicitly.

## UI Thread

* Treat the UI thread as a scarce resource.
* Avoid expensive loops, parsing, serialization, database access or network calls on the UI thread.
* Avoid excessive Dispatcher invocations.
* Batch UI updates where practical.
* Do not update UI-bound collections excessively in tight loops.
* Avoid synchronous waits on background work.
* Keep rendering-related callbacks lightweight.

## Collections

* Use `ObservableCollection<T>` only when collection change notifications are required.
* Do not use `ObservableCollection<T>` as a general-purpose collection.
* Use `List<T>` or other suitable collections for non-observable internal data.
* Avoid replacing entire observable collections when incremental updates are sufficient.
* Avoid thousands of individual collection notifications when a bulk update is more appropriate.
* Keep collection mutations on the correct thread.
* Avoid exposing mutable internal collections unnecessarily.
* Prefer read-only views where consumers should not modify data.

## XAML

* Keep XAML readable and focused.
* Avoid excessively large view files.
* Split complex views into focused controls when it improves maintainability.
* Use resources for repeated values and styles.
* Avoid magic numbers in XAML.
* Keep styles and templates consistent.
* Avoid excessive inline styling.
* Prefer reusable resources over duplicated markup.
* Avoid deeply nested panels.
* Keep visual trees as shallow as practical.
* Use semantic control choices.
* Avoid unnecessary containers.
* Do not overuse triggers when simpler state representation is possible.
* Keep templates understandable.
* Avoid XAML tricks that make behavior hard to discover.

## Layout

* Prefer `Grid` for structured layouts.
* Use `StackPanel` only where its layout behavior is actually appropriate.
* Avoid unnecessary nested panels.
* Avoid fixed sizes unless the design requires them.
* Prefer responsive sizing with `Auto` and `*`.
* Avoid layout configurations that cause excessive measure/arrange passes.
* Be careful with large visual trees inside scrolling containers.
* Avoid disabling virtualization accidentally.

## Virtualization

* Keep UI virtualization enabled for large collections.
* Do not use container layouts that disable virtualization without a reason.
* Avoid wrapping large virtualized item lists in additional scrolling containers.
* Use virtualizing panels where appropriate.
* Verify virtualization when displaying large data sets.
* Avoid rendering thousands of controls simultaneously.
* Prefer paging, incremental loading or virtualization for very large data sets.

## Resources and Styles

* Use shared resources for repeated styles, brushes, templates and dimensions.
* Keep resource dictionaries focused.
* Avoid giant global resource dictionaries.
* Prefer feature-level resources when styles are not truly global.
* Use `StaticResource` by default.
* Use `DynamicResource` only when runtime resource replacement is required.
* Avoid excessive dynamic resource lookups.
* Keep theme resources separated from application logic.
* Avoid hardcoded colors and dimensions when design tokens or resources already exist.

## Dependency Properties

* Use dependency properties only when WPF property-system behavior is required.
* Do not use dependency properties as a replacement for normal CLR properties.
* Keep metadata and callbacks lightweight.
* Avoid expensive work in property-changed callbacks.
* Avoid callbacks with hidden side effects.
* Validate or coerce values only when the control contract requires it.
* Do not expose mutable default values in dependency property metadata.

## Attached Properties and Behaviors

* Use attached properties and behaviors for reusable view-specific behavior.
* Do not use them to hide business logic.
* Keep behaviors focused and predictable.
* Clean up event handlers when behaviors are detached.
* Avoid global attached-property state.
* Prefer explicit behavior over complex XAML hacks.

## Events

* Avoid unnecessary event subscriptions.
* Unsubscribe from long-lived publishers when required.
* Prevent memory leaks from event handlers.
* Prefer weak events where publisher lifetime significantly exceeds subscriber lifetime.
* Keep event handlers small.
* Do not use events as hidden global communication channels.
* Avoid excessive event chaining.

## Memory Management

* Watch for memory leaks caused by:

  * Event subscriptions
  * Timers
  * Static references
  * Long-lived services
  * Cached views
  * Closures
  * Collection views
  * Binding-related references
* Dispose resources correctly.
* Stop timers and background work when no longer needed.
* Avoid retaining closed windows or unloaded views.
* Do not keep unnecessary references to visual elements.
* Profile memory when long-running applications continuously grow.

## Windows and Dialogs

* Keep window lifecycle explicit.
* Avoid creating duplicate windows unintentionally.
* Do not keep hidden windows alive without a reason.
* Separate dialog logic from business logic.
* Prefer dialog services when ViewModels need to request user interaction.
* Keep ownership relationships explicit.
* Avoid application shutdown behavior that depends on accidental window lifetime.

## Navigation

* Keep navigation state explicit.
* Avoid coupling ViewModels directly to concrete views.
* Avoid service locator patterns for view resolution.
* Keep navigation history intentional.
* Dispose or release navigation targets when they are no longer required.
* Do not retain entire navigation graphs unnecessarily.

## Validation

* Validate user input at the appropriate boundary.
* Keep validation logic out of XAML when it becomes complex.
* Prefer reusable validation rules or ViewModel validation for non-trivial cases.
* Display validation errors consistently.
* Do not rely on UI validation as a security boundary.
* Validate again at backend or domain boundaries when required.
* Preserve user input on recoverable errors.

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

## Images and Media

* Load images at an appropriate resolution.
* Avoid decoding images significantly larger than their displayed size.
* Release streams and file handles correctly.
* Avoid locking image files unintentionally.
* Cache images only when there is a clear memory strategy.
* Avoid keeping large bitmaps alive unnecessarily.
* Prefer frozen image resources when they are immutable.

## Security

* Treat all external input as untrusted.
* Never expose secrets, credentials or tokens in UI code.
* Do not store secrets in configuration files committed to source control.
* Avoid leaking sensitive information through logs, dialogs or exception messages.
* Validate file paths and external resources.
* Do not execute external processes or files without explicit validation.
* Avoid insecure deserialization.
* Do not weaken TLS, authentication or certificate validation.
* Prefer secure defaults.
* Never disable security controls for convenience.

## File and Process Access

* Validate file paths before use.
* Avoid assuming files or directories exist.
* Handle permissions and locked files gracefully.
* Avoid arbitrary shell execution.
* Quote and validate process arguments safely.
* Do not concatenate untrusted input into shell commands.
* Avoid elevated privileges unless explicitly required.
* Clean up temporary files when appropriate.

## Error Handling

* Handle expected errors explicitly.
* Do not swallow exceptions.
* Preserve useful exception context.
* Avoid showing raw technical exceptions directly to end users.
* Log enough information for diagnosis without exposing sensitive data.
* Keep user-facing error messages clear and actionable.
* Avoid using exceptions for normal control flow.
* Ensure background exceptions are observed.

## Logging

* Use structured logging.
* Avoid excessive logging on the UI thread.
* Do not log every property change or binding update.
* Never log secrets, tokens, credentials or sensitive user data.
* Include relevant context for operational failures.
* Avoid logging the same exception repeatedly at multiple layers.

## Architecture

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

## Safety Rule

* The UI must remain responsive.
* Do not block the UI thread with I/O or expensive CPU work.
* Do not bypass validation or security controls for convenience.
* Do not introduce hidden cross-thread access.
* Prefer predictable, explicit and testable UI behavior.
