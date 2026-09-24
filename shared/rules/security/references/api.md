# API security

* Authenticate and authorize protected endpoints; validate every request payload and identifier.
* Enforce object-level authorization on every read and write, using the authenticated principal and resource ownership at the operation that accesses the data.
* Bind only explicitly permitted request fields. Do not allow mass assignment of ownership, role, state, or other privileged properties.
* Bound request and response sizes, pagination, query results, and expensive operations.
* Apply rate limits and quotas to authentication, search, uploads, expensive operations, and other abuse-prone endpoints. Keep administrative routes separately protected.
* Define safe retry and idempotency behavior for state-changing requests. Protect against replay and duplicate side effects where relevant.
* Return only authorized fields. Do not expose stack traces, internal models, secrets, or implementation details in API responses or errors.
* Prefer explicit DTOs and schemas; reject unknown or ambiguous fields when accepting them could alter privileged state.
* Keep authorization, validation, serialization, and error responses consistent with the published schema and supported clients.
* Test malformed, oversized, unauthenticated, unauthorized, cross-user, cross-tenant, and duplicate requests within the approved scope.
