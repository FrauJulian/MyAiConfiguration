# C# Security

Apply these rules when implementing or reviewing security-sensitive .NET code. Load the matching shared security rule for the affected API, identity, data, file, network, cryptographic, or dependency boundary as well.

* Validate untrusted input at the boundary and enforce authorization for the specific resource and operation. Static types and client-side checks do not establish trust.
* Use parameterized database APIs. If a query identifier or sort expression cannot be parameterized, select it from a fixed allowlist; never concatenate untrusted input into SQL.
* For file access, canonicalize the resolved path and verify it remains inside the authorized root. Account for reparse points and symlinks when the attacker can affect directory contents.
* For process execution, avoid a shell. Pass executable and arguments separately using APIs supported by the target framework, validate each argument, and restrict executable paths.
* Deserialize into explicit DTOs or allowlisted types. Avoid unsafe polymorphic type activation and unbounded object graphs for untrusted data.
* Bound request and parser work before allocating or processing large values. Apply timeouts to regular expressions that evaluate untrusted input and prefer patterns with predictable complexity.
* Keep secrets in an approved secret store or protected configuration source. Never embed them in assemblies, client bundles, source, diagnostics, or exception messages.
* Use platform TLS and established cryptographic APIs. Do not create custom cryptography or disable certificate validation; use cryptographically secure randomness for security tokens.
* Use framework output encoding and safe APIs for HTML, XML, and other interpreters. Do not build executable markup or queries from untrusted strings.
* Review security-sensitive changes with tests for rejected, malformed, oversized, unauthenticated, and cross-tenant inputs, as applicable.
