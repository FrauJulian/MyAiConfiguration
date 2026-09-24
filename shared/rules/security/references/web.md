# Web and frontend security

* Escape or sanitize untrusted content; never inject untrusted HTML or bypass framework sanitization.
* Protect state-changing browser requests from CSRF where applicable.
* Use `HttpOnly`, `Secure`, and appropriate `SameSite` cookie settings for sensitive sessions.
* Validate redirect targets, avoid sensitive data in URLs, and use CSP and clickjacking protections where applicable.
* Treat frontend code and browser storage as visible and never rely on client-side checks for authorization.
