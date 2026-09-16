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
