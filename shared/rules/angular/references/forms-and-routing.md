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
