# TypeScript Runtime Safety

Apply these rules when handling API payloads, user input, browser data, or other values outside the type system.

* Treat external values as `unknown` until validated. TypeScript annotations and assertions do not validate runtime data.
* Validate untrusted data at system boundaries before storing it, using it for authorization, or passing it to sensitive operations. Use schema validation when external contracts are complex.
* Handle `null` and `undefined` intentionally, and narrow values before use. Avoid implicit coercion and unsafe dynamic property access.
* Prefer allowlists for security-sensitive input. Prevent prototype pollution when merging untrusted objects; avoid unsafe recursive merges and dynamic writes to ordinary object prototypes.
* Treat URL, path, header, query, and redirect destinations as untrusted. Server-side fetches must restrict schemes and destinations, validate every redirect, and enforce response size and timeout limits.
* Use framework-safe text binding and automatic output encoding. Avoid `innerHTML`, `dangerouslySetInnerHTML`, and equivalent escape hatches unless sanitized content is required and a maintained sanitizer is applied.
* For cookie-based authentication, preserve secure cookie attributes and the application's CSRF protections. Do not store authentication secrets in browser-accessible storage without an explicit threat model and security design.
* Never expose secrets or sensitive data in output, logs, or errors. Client-side validation and route guards do not replace server-side authentication, authorization, or validation.
* Bound input size, nesting, parsing work, and response size before processing untrusted JSON or other structured data.
