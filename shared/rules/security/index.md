# Security Baseline

Apply this language- and framework-independent baseline to every code, configuration, infrastructure, and review task. Use the platform's established controls to implement it. Load focused security rules only for boundaries affected by the task; triggers are listed in the global instructions.

* Prioritize confidentiality, integrity, and availability. When security and performance conflict, preserve the security control and find a more efficient implementation; explain unavoidable cost.
* Identify trust boundaries and likely abuse paths. Treat external input as untrusted; validate it before use and enforce authorization at the resource or operation boundary.
* Default to deny, least privilege, and fail-closed behavior. Keep protections consistent across alternate paths, background work, caches, and administrative operations.
* Bound attacker-controlled work: input and output sizes, computation, memory, concurrency, retries, and time. Use timeouts, quotas, and rate limits where needed to prevent resource exhaustion and denial of service.
* Protect secrets and sensitive data throughout their lifecycle. Minimize collection and retention; never hardcode, commit, log, expose, or send them to unauthorized destinations.
* Use maintained platform mechanisms for authentication, authorization, cryptography, serialization, and transport security. Do not invent cryptography or bypass validation, certificate checks, or other controls.
* Keep dependencies and privileges minimal. Return safe errors and diagnostics without exposing secrets or internal details.
