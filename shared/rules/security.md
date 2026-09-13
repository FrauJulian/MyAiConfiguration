# Security baseline

Apply this baseline to every code, configuration, infrastructure, or review task.

* Treat external input as untrusted and validate at trust boundaries.
* Prefer secure defaults, least privilege, explicit authorization, and fail-closed behavior.
* Never hardcode, commit, log, expose, or weaken protections for secrets and credentials.
* Use established framework and platform security mechanisms; do not invent cryptography or bypass validation, authentication, authorization, or TLS checks.
* Keep dependencies minimal and from trusted sources.
* Do not disclose sensitive data or internal implementation details in user-facing errors or diagnostics.
* Load the applicable focused security rule before changing authentication, web/UI, APIs, databases, files, network access, cryptography, secrets, or supply-chain configuration.
