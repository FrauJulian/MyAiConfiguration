# Security Baseline

Apply this language- and framework-independent baseline to every code, configuration, infrastructure, and review task. Use the platform's established controls to implement it. Load focused security rules only for boundaries affected by the task; triggers are listed in the global instructions.

* Prioritize confidentiality, integrity, and availability. When security and performance conflict, preserve the security control and find a more efficient implementation; explain unavoidable cost.
* Identify trust boundaries and likely abuse paths. Treat external input as untrusted; validate it before use and enforce authorization at the resource or operation boundary.
* Default to deny, least privilege, and fail-closed behavior. Keep protections consistent across alternate paths, background work, caches, and administrative operations.
* Bound attacker-controlled work: input and output sizes, computation, memory, concurrency, retries, and time. Use timeouts, quotas, and rate limits where needed to prevent resource exhaustion and denial of service.
* Protect secrets and sensitive data throughout their lifecycle. Minimize collection and retention; never hardcode, commit, log, expose, or send them to unauthorized destinations.
* Use maintained platform mechanisms for authentication, authorization, cryptography, serialization, and transport security. Do not invent cryptography or bypass validation, certificate checks, or other controls.
* Keep dependencies and privileges minimal. Return safe errors and diagnostics without exposing secrets or internal details.

## Focused Security Rules

Load only the topic rules that match the affected boundary.

| Topic | Codex rule | Claude skill |
| --- | --- | --- |
| Authentication, authorization, sessions, tokens, permissions, and tenants | `references/auth.md` | `rules-security-auth` |
| HTTP, requests, serialization, and endpoints | `references/api.md` | `rules-security-api` |
| Browsers, cookies, redirects, XSS, and CSRF | `references/web.md` | `rules-security-web` |
| Databases, queries, persistence, and sensitive data | `references/data.md` | `rules-security-data` |
| Files, uploads, archives, paths, processes, IPC, and deserialization | `references/files.md` | `rules-security-files` |
| Network access, URLs, proxies, TLS, and SSRF | `references/network.md` | `rules-security-network` |
| Cryptography, secrets, keys, and credentials | `references/crypto.md` | `rules-security-crypto` |
| Dependencies, packages, plugins, builds, deployment, and CI | `references/supply-chain.md` | `rules-security-supply-chain` |
| Active security testing and exploit validation | `references/testing.md` | `rules-security-testing` |
