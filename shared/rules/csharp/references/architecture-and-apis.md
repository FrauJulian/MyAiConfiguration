# C# Architecture and APIs

Apply these rules when designing public APIs, service boundaries, or application architecture.

* Give APIs explicit, strongly typed contracts. Keep trusted internal paths free of checks already done at the boundary.
* Separate request models from persistence and domain models. Bind only fields the caller may set, and project only fields the caller may read.
* Authenticate and authorize before accessing protected resources. Keep the decision close to the protected operation, enforce resource ownership and tenant scope in the data access path, not only in the UI or route layer, and fail closed when identity, ownership, or policy evaluation is unavailable.
* Use explicit, bounded pagination for potentially large collections.
* Keep application, domain, and infrastructure concerns separate. Avoid cross-layer coupling and service-locator patterns.
* Use dependency injection when substitution or lifecycle management is needed. Keep dependencies explicit and avoid excessive constructor dependencies.
* Preserve established project and public API conventions unless a concrete compatibility or correctness issue requires a change.
