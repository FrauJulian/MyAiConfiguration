# Java Architecture and APIs

Apply these rules when designing public APIs, service boundaries, or application structure.

* Give APIs explicit request, response, and error contracts. Validate external input at the boundary without scattering redundant checks through trusted internal code.
* Separate transport models, domain models, and persistence entities. Accept only fields callers may set and return only fields they may read.
* Authorize the specific resource and operation where data is accessed or changed. Preserve ownership and tenant scope across alternate paths and background work.
* Bound payloads, page sizes, query complexity, and operation cost. Use pagination or streaming for potentially large results.
* Keep domain decisions separate from transport, persistence, and framework wiring. Make dependencies explicit; use dependency injection for real lifecycle or substitution needs.
* Prefer composition and small contracts at real boundaries. Avoid service locators, broad base classes, reflection, and wrappers without a concrete purpose.
* Preserve existing API and serialization behavior unless the task requires a change. Treat changes to nullability, ordering, exception types, and collection mutability as compatibility changes.
