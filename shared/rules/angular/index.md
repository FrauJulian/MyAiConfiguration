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

## Safety Rule

* Angular frontend code is never a security boundary.
* Client-side validation, guards, hidden controls and disabled UI elements do not replace backend enforcement.
* Do not bypass Angular's built-in security mechanisms without a verified and explicit reason.
* Prefer safe framework defaults over custom low-level behavior.

## Detailed guidance

Read the matching reference file before working in that area:

| Read this reference for... | ...this kind of work |
| --- | --- |
| `references/components-and-state.md` | Component structure, signal-based state |
| `references/templates-and-styling.md` | Template markup, CSS/styling |
| `references/rxjs.md` | RxJS observables and subscriptions |
| `references/services-and-http.md` | Dependency injection, services, HTTP/API access |
| `references/forms-and-routing.md` | Reactive forms, routing |
| `references/security-and-accessibility.md` | Security, DOM/browser APIs, accessibility |
| `references/performance.md` | Performance work and its priority order |
| `references/testing-and-architecture.md` | Testing, architecture, code quality, dependency rules |
