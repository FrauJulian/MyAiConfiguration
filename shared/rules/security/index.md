# Security Baseline

Apply this short baseline to every code, configuration, infrastructure, and review task. Load only the focused security rules that match the affected boundary; their triggers are listed in the global instructions.

* Treat external input as untrusted and validate it at the relevant trust boundary.
* Use secure defaults, least privilege, explicit authorization, and fail-closed behavior.
* Never hardcode, commit, log, expose, or weaken protections for secrets and credentials.
* Use established platform security mechanisms. Do not invent cryptography or bypass validation, authentication, authorization, or TLS checks.
* Keep dependencies minimal and trusted; avoid disclosing sensitive data or internal details in errors and diagnostics.
