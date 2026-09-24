## Components

* Prefer standalone components, directives, and pipes for new work. Avoid introducing `NgModule` unless the existing architecture requires it.
* Keep components small; move substantial business logic to a focused service or domain layer.
* Keep dependencies explicit and follow the feature architecture. Avoid god components, god services, unnecessary wrappers, and abstractions without a concrete need.
* Use `ChangeDetectionStrategy.OnPush` unless there is a concrete reason not to.
* Prefer signal-based state for local component state.
* Prefer `computed` for derived state.
* Prefer `effect` only for actual side effects.
* Do not use `effect` as a replacement for normal data flow.
* Keep component state minimal.
* Avoid duplicating derived state.
* Prefer immutable state updates.
* Avoid direct mutation of shared state.
* Keep inputs and outputs strongly typed.
* Prefer signal-based inputs and outputs when consistent with the project.
* Avoid unnecessary two-way binding.
* Avoid unnecessary component-to-component coupling.
* Prefer explicit data flow from parent to child and explicit events upward.
* Do not expose internal component state unnecessarily.
* Use lifecycle hooks only when required.
* Avoid complex initialization logic inside constructors.

## Signals and State

* Prefer signals for local and synchronous reactive state.
* Prefer `computed` for derived values.
* Keep signals private when external mutation is not intended.
* Expose readonly state where practical.
* Avoid storing values that can be derived from existing state.
* Avoid circular signal dependencies.
* Avoid side effects inside `computed`.
* Keep effects small and deterministic.
* Clean up resources created by effects.
* Do not use global state unless multiple unrelated parts of the application genuinely need it.
* Do not introduce a state-management library without a clear requirement.
