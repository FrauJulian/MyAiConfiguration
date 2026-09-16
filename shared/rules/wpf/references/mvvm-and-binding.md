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
