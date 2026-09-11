# Angular Code Guidelines

* Use modern Angular patterns and current framework conventions.
* Prefer standalone components, directives and pipes for new code.
* Avoid introducing `NgModule` unless the existing project architecture requires it.
* Keep components small and focused.
* Keep templates simple.
* Move complex logic out of templates.
* Keep business logic out of components where practical.
* Prefer services, facades or dedicated domain logic for non-trivial behavior.
* Avoid god components and god services.
* Keep dependencies explicit.
* Prefer composition over inheritance.
* Avoid unnecessary abstractions.
* Avoid unnecessary wrapper components.
* Follow the existing project architecture unless there is a strong reason to change it.

## Components

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

## Templates

* Keep expressions short and readable.
* Do not execute expensive methods from templates.
* Avoid function calls in templates when their result can be derived or cached.
* Avoid complex conditions directly in markup.
* Prefer derived state in TypeScript over repeated template expressions.
* Use Angular control flow syntax such as `@if`, `@for` and `@switch` for new code.
* Always provide stable tracking for repeated collections.
* Avoid deeply nested template structures.
* Split large templates into focused components when it improves maintainability.
* Avoid unnecessary DOM elements.
* Use semantic HTML.
* Prefer native HTML behavior before custom implementations.
* Keep accessibility in mind when choosing elements and interactions.

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

## RxJS

* Use RxJS for asynchronous streams, events and complex reactive flows.
* Do not use RxJS when simple synchronous signals are sufficient.
* Prefer declarative observable pipelines.
* Avoid nested `subscribe`.
* Avoid manual subscriptions where `async`, signals or framework helpers are sufficient.
* Prefer `takeUntilDestroyed` or equivalent Angular lifecycle integration for manual subscriptions.
* Always consider subscription lifetime.
* Avoid memory leaks from unmanaged subscriptions.
* Use the correct flattening operator for the required semantics.
* Do not use `switchMap`, `mergeMap`, `concatMap` or `exhaustMap` interchangeably.
* Avoid unnecessary `Subject` usage.
* Prefer exposing observables instead of exposing mutable subjects.
* Prefer `BehaviorSubject` only when a current value is actually required.
* Avoid excessive observable chains for simple state.
* Avoid converting repeatedly between signals and observables without need.

## Dependency Injection

* Prefer Angular dependency injection for application services.
* Keep injected dependencies minimal.
* Avoid service locator patterns.
* Prefer `inject()` where it improves readability and is consistent with the project.
* Do not inject services that are not used.
* Scope services intentionally.
* Prefer application-wide singletons only for truly shared stateless or coordinated state.
* Avoid storing request-specific or component-specific mutable state in root services.
* Use injection tokens for configuration or abstractions where appropriate.
* Do not create interfaces only to satisfy dependency injection when no abstraction is needed.

## Services

* Keep services focused on a clear responsibility.
* Avoid large catch-all services.
* Separate API access, domain logic and UI state where practical.
* Avoid leaking transport models throughout the application.
* Do not expose mutable internal state directly.
* Prefer readonly APIs for state consumers.
* Avoid hidden side effects.
* Keep service methods predictable.
* Do not use services merely to move poorly structured component code elsewhere.

## HTTP and APIs

* Keep API access centralized and strongly typed.
* Prefer dedicated API clients or data-access services.
* Do not use `any` for API responses.
* Treat all server responses as untrusted at runtime.
* Validate external data when the contract is security- or correctness-critical.
* Keep DTOs separate from domain models when their responsibilities differ.
* Avoid duplicate API calls.
* Cache only when the invalidation strategy is clear.
* Avoid manual URL string construction when typed helpers or centralized endpoints are available.
* Use interceptors only for cross-cutting concerns.
* Do not put unrelated business logic into HTTP interceptors.
* Handle cancellation where appropriate.
* Handle expected error states explicitly.

## Forms

* Prefer reactive forms for non-trivial forms.
* Keep forms strongly typed.
* Avoid untyped forms.
* Keep validation rules centralized and reusable where practical.
* Validate on both client and server where required.
* Never treat client-side validation as a security boundary.
* Keep form state separate from domain state when useful.
* Avoid large components that combine layout, validation, persistence and business logic.
* Display validation errors consistently.
* Preserve user input when recoverable errors occur.

## Routing

* Keep route definitions explicit and predictable.
* Prefer lazy loading for larger feature areas.
* Avoid loading large feature bundles eagerly without need.
* Use route guards only for navigation behavior, not as a security boundary.
* Authorization must still be enforced on the backend.
* Keep resolvers focused.
* Avoid expensive work during navigation unless required.
* Keep route parameters strongly typed at application boundaries where practical.
* Do not rely on client-side routing state for sensitive authorization decisions.

## Performance

* Use `OnPush`.
* Use stable tracking in loops.
* Avoid unnecessary change detection triggers.
* Avoid repeated expensive template calculations.
* Avoid unnecessary subscriptions.
* Avoid unnecessary DOM rendering.
* Lazy-load large features and heavy dependencies where appropriate.
* Avoid large initial bundles.
* Avoid importing full libraries when only a small part is required.
* Avoid unnecessary deep cloning.
* Avoid unnecessary object and array recreation in hot paths.
* Keep state updates targeted.
* Avoid unnecessary global state updates.
* Measure bundle size and runtime performance before micro-optimizing.
* Prefer architectural improvements over template-level micro-optimizations.

## Security

* Treat all external data as untrusted.
* Never bypass Angular sanitization without a verified reason.
* Avoid direct DOM manipulation.
* Avoid `innerHTML` with untrusted content.
* Avoid `bypassSecurityTrust*` unless explicitly required and the input is fully controlled.
* Never expose secrets in frontend code.
* Never store sensitive credentials in the Angular application.
* Do not rely on frontend checks for authorization.
* Enforce authentication and authorization on the backend.
* Avoid leaking sensitive information through logs or error messages.
* Use secure cookie or token handling according to the application's authentication architecture.
* Avoid storing sensitive tokens in insecure browser storage without a deliberate security decision.
* Do not disable security controls for convenience.

## DOM and Browser APIs

* Prefer Angular APIs and declarative templates over direct DOM manipulation.
* Use `Renderer2` only when direct rendering abstraction is actually needed.
* Avoid accessing globals directly when it harms testability or SSR compatibility.
* Consider SSR and hydration compatibility for browser-specific code.
* Guard access to `window`, `document`, `localStorage` and similar browser-only APIs when SSR is supported.
* Clean up event listeners, observers and timers.
* Avoid layout thrashing in performance-sensitive code.

## Accessibility

* Use semantic HTML.
* Preserve keyboard navigation.
* Ensure interactive elements are actually interactive elements.
* Do not replace buttons with clickable `div` elements.
* Provide labels for form controls.
* Maintain visible focus behavior.
* Use ARIA only when native HTML semantics are insufficient.
* Avoid unnecessary custom widgets.
* Keep accessible names and states synchronized with UI state.

## Styling

* Keep styles scoped and predictable.
* Avoid unnecessary global CSS.
* Follow the project's styling strategy consistently.
* Avoid excessive specificity.
* Avoid `!important` unless there is a concrete reason.
* Prefer reusable design tokens and shared styles over duplicated magic values.
* Keep component styles focused on component concerns.
* Avoid styling based on fragile DOM structure.
* Do not mix multiple styling approaches without need.

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

## Performance Priority

Prioritize Angular performance work in this order:

* Application architecture
* Network and API behavior
* Bundle size and lazy loading
* State architecture
* Change detection
* Rendering and DOM complexity
* RxJS and subscription behavior
* Memory allocations
* CPU micro-optimizations

Never optimize based purely on assumptions.

## Safety Rule

* Angular frontend code is never a security boundary.
* Client-side validation, guards, hidden controls and disabled UI elements do not replace backend enforcement.
* Do not bypass Angular's built-in security mechanisms without a verified and explicit reason.
* Prefer safe framework defaults over custom low-level behavior.
