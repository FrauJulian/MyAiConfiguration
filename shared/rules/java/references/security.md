# Java Security

Apply these rules to security-sensitive Java code. Load the focused shared security rule for each affected boundary as well.

* Validate untrusted input before expensive work and authorize the specific resource and operation. Java types and client-side validation do not establish trust.
* Use parameterized database APIs such as `PreparedStatement`. Select dynamic identifiers or sort expressions from a fixed allowlist; never concatenate untrusted data into SQL.
* Resolve file paths against an authorized root and account for symlinks and replacement races when an attacker can change the filesystem. Limit file size and processing work.
* Use `ProcessBuilder` with an executable and separate arguments; avoid shell interpretation. Restrict executable paths and validate attacker-controlled arguments.
* Deserialize into explicit allowed types. Avoid native Java serialization and unrestricted polymorphic type activation for untrusted data; bound input size and nesting.
* Use the platform's maintained TLS, cryptographic, and secure-random APIs. Do not disable certificate validation or build custom cryptography.
* Keep secrets out of source, logs, exception messages, and serialized responses. Use approved secret storage and clear ownership for sensitive data.
* Use context-appropriate encoding for HTML, XML, and other interpreters. Test rejected, malformed, oversized, unauthorized, and cross-tenant inputs where relevant.
