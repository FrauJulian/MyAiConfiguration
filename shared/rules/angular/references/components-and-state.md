## Components

* Prefer standalone components, directives, and pipes for new work. Avoid introducing `NgModule` unless the existing architecture requires it.
* Keep components small; move substantial business logic to a focused service or domain layer.
* Keep dependencies explicit and follow the feature architecture. Avoid god components, god services, unnecessary wrappers, and abstractions without a concrete need.
* Use `ChangeDetectionStrategy.OnPush` unless there is a concrete reason not to.
* Keep component state minimal and prefer immutable state updates.
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
* Derive values with `computed` instead of storing or duplicating them; keep `computed` free of side effects.
* Keep signals private when external mutation is not intended, and expose readonly state where practical.
* Avoid circular signal dependencies.
* Use `effect` only for actual side effects, not as a replacement for normal data flow. Keep effects small and deterministic, and clean up resources they create.
* Do not use global state unless multiple unrelated parts of the application genuinely need it.
* Do not introduce a state-management library without a clear requirement.
