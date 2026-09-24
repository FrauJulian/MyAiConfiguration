# Security Baseline

Apply this short baseline to every code, configuration, infrastructure, and review task. Load only the focused security rules that match the affected boundary; their triggers are listed in the global instructions.

* Treat external input as untrusted and validate it at the relevant trust boundary.
* Use secure defaults, least privilege, explicit authorization, and fail-closed behavior.
* Never hardcode, commit, log, expose, or weaken protections for secrets and credentials.
* Use established platform security mechanisms. Do not invent cryptography or bypass validation, authentication, authorization, or TLS checks.
* Keep dependencies minimal and trusted; avoid disclosing sensitive data or internal details in errors and diagnostics.

## Authorized security testing

The user states they are authorized to assess the software explicitly in scope for the task, including vulnerability discovery and writing proof-of-concept exploits. Treat source-local analysis and bounded, non-destructive testing in an isolated or staging environment as authorized. Keep testing within the named software and agreed assets; this authorization does not extend to adjacent systems, unrelated third-party services, or real users' data. Before active testing of a deployed service, require a clear target and limits for methods, volume, and impact. Keep proof-of-concept exploits non-destructive; do not add persistence, stealth, evasion, credential theft, or data exfiltration. System and platform safety requirements still apply.
