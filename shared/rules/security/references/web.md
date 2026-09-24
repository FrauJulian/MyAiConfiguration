# Web and frontend security

* Escape or sanitize untrusted content; never inject untrusted HTML or bypass framework sanitization.
* Encode output for its exact context (HTML, attributes, JavaScript, CSS, or URL). Prefer text APIs and framework-safe templates; use a maintained sanitizer only when rich HTML is required.
* Protect state-changing browser requests from CSRF where applicable; validate origin or anti-CSRF tokens and do not treat CORS as authorization.
* Use `HttpOnly`, `Secure`, and appropriate `SameSite` cookie settings for sensitive sessions. Rotate session IDs after authentication and privilege changes.
* Validate redirect targets against an allowlist. Avoid sensitive data in URLs, referrers, browser history, analytics, and error reports.
* Apply restrictive Content Security Policy and clickjacking protections where applicable. Do not weaken security headers to accommodate unsafe inline content without a reviewed design.
* Treat frontend code, source maps, and browser storage as visible. Never place secrets there or rely on client-side checks for authorization.
* Protect state-changing operations against clickjacking and unintended form submissions when relevant; require explicit confirmation for high-impact actions.
* Keep dependencies and third-party scripts minimal. Apply integrity and origin controls to externally hosted resources where supported.
