# Security Guidelines

Security is a default requirement for all code, architecture, configuration and infrastructure changes.

## Core Principles

* Prefer secure defaults.
* Apply least privilege everywhere.
* Minimize exposed attack surface.
* Treat all external input as untrusted.
* Never trust client-side validation alone.
* Fail securely.
* Prefer deny-by-default over allow-by-default for sensitive operations.
* Keep security controls explicit and auditable.
* Do not weaken security for convenience.
* Do not bypass security mechanisms to make code easier to implement.
* Do not introduce insecure temporary solutions.
* Prefer simple, well-understood security mechanisms over custom cryptography or clever security logic.

## Secrets and Credentials

* Never hardcode passwords, API keys, tokens, connection strings, private keys or secrets.
* Never commit secrets to source control.
* Never log secrets or credentials.
* Never expose secrets in exceptions, diagnostics or UI messages.
* Use secure secret storage appropriate to the environment.
* Prefer short-lived credentials where supported.
* Rotate compromised credentials immediately.
* Do not reuse credentials across environments.
* Keep development, staging and production credentials separate.
* Avoid secrets in URLs, query strings or command-line arguments.
* Do not store secrets in frontend code.
* Do not include real credentials in examples, tests or fixtures.

## Authentication

* Use established authentication standards and framework capabilities.
* Do not implement custom authentication protocols without a strong reason.
* Store passwords only using modern password hashing algorithms designed for password storage.
* Never store plaintext passwords.
* Never use reversible encryption for password storage.
* Support secure session expiration.
* Invalidate sessions or tokens when security-sensitive account state changes.
* Protect authentication endpoints against brute-force abuse where applicable.
* Avoid exposing whether an account exists unless required.
* Require stronger authentication for security-sensitive actions where appropriate.

## Authorization

* Enforce authorization on the server side.
* Never rely on hidden UI elements, disabled buttons or frontend guards as authorization.
* Check authorization for every sensitive operation.
* Prefer explicit permission checks.
* Use least-privilege roles and permissions.
* Avoid broad administrative permissions unless required.
* Prevent horizontal privilege escalation between users or tenants.
* Prevent vertical privilege escalation between permission levels.
* Verify ownership of resources before access or modification.
* Do not trust identifiers supplied by the client as proof of authorization.

## Input Validation

* Validate all input from users, APIs, files, databases, queues, environment variables and external systems.
* Validate type, length, range, format and allowed values.
* Prefer allowlists over denylists.
* Reject unexpected input.
* Normalize input before validation when appropriate.
* Do not rely solely on client-side validation.
* Validate identifiers before using them for resource access.
* Validate uploaded files by content, size and expected type where applicable.
* Do not trust file extensions alone.

## Injection Prevention

* Never concatenate untrusted input into SQL.
* Use parameterized queries or ORM parameter binding.
* Never concatenate untrusted input into shell commands.
* Avoid executing shell commands when a direct API is available.
* Validate and escape command arguments when process execution is required.
* Prevent LDAP, XPath, template and expression injection where applicable.
* Avoid dynamic code execution.
* Avoid `eval`, dynamic compilation and equivalent mechanisms unless strictly required.
* Treat template engines and interpreters as security boundaries.

## Web Security

* Prevent Cross-Site Scripting by using framework escaping and sanitization.
* Never inject untrusted HTML directly.
* Avoid bypassing framework sanitization.
* Protect state-changing browser requests against CSRF where applicable.
* Use secure cookies for sensitive session data.
* Use `HttpOnly` for authentication cookies where possible.
* Use `Secure` cookies in HTTPS environments.
* Configure `SameSite` appropriately.
* Use appropriate Content Security Policy where applicable.
* Avoid leaking sensitive data through referrers or URLs.
* Validate redirect targets to prevent open redirects.
* Protect against clickjacking where applicable.

## API Security

* Authenticate sensitive endpoints.
* Authorize every protected operation.
* Validate all request payloads.
* Apply reasonable request-size limits.
* Apply pagination and bounded queries.
* Apply rate limiting where abuse is possible.
* Avoid exposing internal models directly when this leaks implementation details.
* Return only data the caller is authorized to access.
* Do not expose stack traces or internal exception details.
* Avoid excessive information in error responses.
* Version public APIs intentionally.
* Protect administrative endpoints separately where appropriate.

## Data Protection

* Collect only data that is actually required.
* Minimize storage of sensitive data.
* Classify sensitive data explicitly.
* Encrypt sensitive data in transit.
* Encrypt sensitive data at rest where appropriate.
* Do not implement custom encryption algorithms.
* Use established cryptographic libraries.
* Do not use obsolete cryptographic algorithms.
* Do not use hardcoded encryption keys.
* Use cryptographically secure random number generation for security-sensitive values.
* Avoid exposing personal or sensitive data in logs.
* Delete sensitive data when it is no longer required.

## Cryptography

* Never design custom cryptographic primitives.
* Use current, established cryptographic standards.
* Use authenticated encryption when confidentiality and integrity are required.
* Verify signatures before trusting signed content.
* Validate certificates correctly.
* Never disable certificate validation.
* Never accept all TLS certificates.
* Do not downgrade TLS security.
* Use secure randomness for tokens, nonces, identifiers and keys.
* Never use predictable random generators for security-sensitive values.

## Tokens and Sessions

* Treat tokens as secrets.
* Keep token lifetime as short as practical.
* Validate issuer, audience, signature and expiration where applicable.
* Do not accept unsigned tokens unless explicitly designed and safe.
* Do not trust token contents before validation.
* Avoid storing long-lived access tokens in insecure browser storage.
* Rotate refresh tokens where appropriate.
* Revoke compromised tokens where possible.
* Prevent replay attacks where the protocol requires it.

## File Security

* Validate file names and paths.
* Prevent path traversal.
* Never concatenate untrusted input directly into filesystem paths.
* Restrict file access to intended directories.
* Use generated server-side file names where appropriate.
* Enforce file size limits.
* Validate uploaded content.
* Do not execute uploaded files.
* Store uploads outside executable web roots where applicable.
* Handle archive extraction safely.
* Prevent zip-slip and equivalent path traversal attacks.
* Avoid following untrusted symbolic links where security-sensitive.

## Serialization

* Treat deserialized input as untrusted.
* Avoid insecure polymorphic deserialization.
* Avoid deserializing arbitrary runtime types.
* Use explicit schemas or known DTOs.
* Restrict type resolution.
* Do not deserialize executable objects or behavior.
* Validate deserialized data before use.
* Avoid insecure legacy serializers.

## Database Security

* Use parameterized queries.
* Use least-privilege database accounts.
* Do not use administrative database accounts for normal application traffic.
* Restrict schema modification permissions in runtime accounts.
* Protect connection strings.
* Avoid exposing raw database errors.
* Limit query size and result sets.
* Prevent tenant data leakage.
* Verify tenant boundaries in every relevant query.
* Use transactions where integrity requires atomicity.

## Logging and Monitoring

* Never log secrets.
* Never log passwords.
* Never log authentication tokens.
* Avoid logging sensitive personal data.
* Use structured logging.
* Include security-relevant context without exposing sensitive values.
* Log authentication and authorization failures where appropriate.
* Log suspicious or high-risk actions where appropriate.
* Avoid log injection by treating user input as data.
* Do not let logging failures break critical application behavior.
* Ensure logs have appropriate access controls.

## Error Handling

* Fail securely.
* Do not expose internal stack traces to users.
* Do not reveal implementation details unnecessarily.
* Preserve diagnostic detail internally where safe.
* Avoid different error responses that reveal sensitive existence checks where not required.
* Do not swallow security-relevant exceptions.
* Do not continue execution after critical validation or authorization failures.

## Dependencies

* Keep dependencies minimal.
* Prefer maintained and widely used packages.
* Avoid abandoned packages.
* Avoid unnecessary dependencies for trivial functionality.
* Keep dependencies updated with security patches.
* Review dependency changes before adoption.
* Do not blindly update major versions without compatibility review.
* Remove unused dependencies.
* Treat transitive dependencies as part of the attack surface.
* Verify package identity before installation.
* Avoid untrusted package sources.
* Respect lockfiles.

## Supply Chain Security

* Pin dependency versions where appropriate.
* Protect build and deployment pipelines.
* Do not expose CI/CD credentials.
* Use least privilege for pipeline identities.
* Review third-party actions, plugins and build scripts.
* Avoid executing untrusted build scripts.
* Verify artifacts and sources where practical.
* Keep generated artifacts traceable to source.
* Do not publish secrets in build logs or artifacts.

## Configuration

* Use secure production defaults.
* Do not enable debug mode in production.
* Do not expose development endpoints in production.
* Separate environment-specific configuration.
* Validate security-sensitive configuration at startup.
* Fail startup when mandatory security configuration is missing.
* Do not silently fall back to insecure settings.
* Protect configuration files containing sensitive values.

## Network Security

* Use HTTPS for sensitive or authenticated communication.
* Do not disable TLS validation.
* Restrict outbound network access where practical.
* Restrict inbound services to required ports and interfaces.
* Use timeouts for network operations.
* Limit retries to avoid amplification or denial-of-service behavior.
* Validate remote endpoints where SSRF is possible.
* Do not allow arbitrary user-controlled URLs for privileged server-side requests.
* Block access to internal network ranges when handling untrusted remote URLs where applicable.

## SSRF Prevention

* Treat user-controlled URLs as dangerous.
* Validate schemes.
* Prefer allowlisted hosts.
* Resolve and verify target addresses where necessary.
* Prevent access to localhost, metadata endpoints and internal networks where not explicitly required.
* Revalidate after redirects.
* Limit redirects.
* Apply request timeouts and response-size limits.

## Concurrency and Resource Abuse

* Bound concurrency.
* Avoid unbounded task creation.
* Avoid unbounded queues.
* Limit request sizes.
* Limit collection sizes when processing external input.
* Apply timeouts to external operations.
* Apply cancellation where practical.
* Prevent expensive operations from being triggered repeatedly without limits.
* Protect endpoints against denial-of-service through algorithmic complexity.
* Avoid user-controlled regular expressions that may cause catastrophic backtracking.

## Memory Safety and Resource Management

* Dispose files, streams, sockets and other resources correctly.
* Prevent resource leaks.
* Avoid retaining sensitive data in memory longer than necessary.
* Avoid unsafe code unless explicitly required.
* Review pointer and memory operations carefully.
* Avoid exposing raw memory or buffers across trust boundaries.
* Clear sensitive buffers where warranted.

## Multi-Tenant Systems

* Treat tenant boundaries as security boundaries.
* Scope every tenant-owned query explicitly.
* Never trust tenant identifiers from the client without authorization.
* Prevent cross-tenant cache leakage.
* Prevent cross-tenant logging or diagnostics leakage.
* Keep tenant-specific secrets isolated.
* Test horizontal privilege escalation explicitly.

## Frontend Security

* Assume frontend code and data are visible to the user.
* Never embed secrets in frontend applications.
* Never rely on frontend checks for authorization.
* Treat browser storage as potentially accessible to malicious scripts.
* Avoid storing sensitive long-lived tokens unnecessarily.
* Escape or sanitize untrusted content.
* Do not bypass framework security controls without explicit justification.

## Desktop Application Security

* Treat local files and IPC input as untrusted where applicable.
* Do not assume local users or processes are trusted.
* Avoid storing secrets in plaintext configuration.
* Protect locally cached sensitive data.
* Validate update packages and downloaded executables.
* Do not execute arbitrary files or commands from untrusted input.
* Use least privilege and avoid unnecessary elevation.

## Security-Sensitive Changes

Changes affecting any of the following require additional scrutiny:

* Authentication
* Authorization
* Cryptography
* Secrets
* User permissions
* File access
* Process execution
* Network access
* Input validation
* Serialization
* Database access
* Payment or financial data
* Personal or confidential data
* Admin functionality
* Deployment or infrastructure security

For security-sensitive changes:

* Prefer established framework functionality.
* Review trust boundaries.
* Review failure behavior.
* Review privilege requirements.
* Review input validation.
* Review logging for data leakage.
* Review backward compatibility for security implications.
* Add or update relevant security tests.

## Security Testing

* Test authorization failures.
* Test invalid and malicious input.
* Test boundary values.
* Test unauthenticated access.
* Test unauthorized resource access.
* Test cross-user and cross-tenant access where applicable.
* Test expired and invalid credentials.
* Test malformed payloads.
* Test path traversal where files are involved.
* Test injection risks where interpreters or databases are involved.
* Test rate and resource limits where abuse is realistic.
* Preserve regression tests for discovered security issues.

## Agent Rules

* Never intentionally weaken security controls without explicit user instruction.
* Never disable certificate validation, authentication, authorization, validation or security middleware to solve a problem.
* Never add hardcoded secrets.
* Never expose sensitive data for debugging convenience.
* Never bypass a security check because it blocks implementation.
* Never assume trusted input without a clearly defined trust boundary.
* Never silently choose a less secure implementation because it is easier.
* If a requested change creates a meaningful security risk, clearly identify the risk before proceeding.
* If requirements are ambiguous in a security-sensitive area, ask the user instead of making an autonomous security decision.

## Priority Order

Prioritize security decisions in this order:

* Prevent unauthorized access
* Protect sensitive data
* Preserve integrity
* Minimize privileges
* Minimize attack surface
* Validate trust boundaries
* Maintain availability
* Preserve auditability
* Optimize usability and performance only within acceptable security constraints

Security must not be traded away for convenience without an explicit and informed decision.
