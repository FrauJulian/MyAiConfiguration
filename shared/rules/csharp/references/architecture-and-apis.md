# C# Architecture and APIs

Apply these rules when designing public APIs, service boundaries, or application architecture.

* Give APIs explicit, strongly typed contracts. Validate external input at the boundary and keep trusted internal paths free of redundant checks.
* Separate request models from persistence and domain models. Bind only fields the caller may set, and project only fields the caller may read.
* Authenticate and authorize before accessing protected resources. Enforce resource ownership and tenant scope in the data access path, not only in the UI or route layer.
* Bound page size, payload size, query complexity, and operation cost. Use explicit pagination for potentially large collections.
* Keep application, domain, and infrastructure concerns separate. Avoid cross-layer coupling and service-locator patterns.
* Use dependency injection when substitution or lifecycle management is needed. Keep dependencies explicit and avoid excessive constructor dependencies.
* Prefer composition over inheritance; use inheritance only when the contract requires it. Seal types when extension is not intended.
* Keep classes and methods focused. Avoid wrappers, abstractions, reflection, and global mutable state without a concrete need.
* Preserve established project and public API conventions unless a concrete compatibility or correctness issue requires a change.
* Keep authorization decisions close to the protected operation and fail closed when identity, ownership, or policy evaluation is unavailable.
* Avoid returning persistence entities, internal exception details, or fields that are not part of the public contract.
