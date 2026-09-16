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
