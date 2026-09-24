# C# Safety and Error Handling

Apply these rules when handling external input, failures, logs, or sensitive information.

* Treat external data as untrusted and validate it at system boundaries. Do not rely on static types to validate runtime input.
* Validate size, range, format, and allowed values before expensive parsing or allocation. Keep validation consistent with downstream business and security constraints.
* Fail fast for invalid arguments or impossible state. Do not use exceptions for routine control flow or swallow unexpected exceptions.
* Preserve useful exception context without exposing secrets, personal data, or internal details in logs, APIs, or user-facing errors.
* Use structured logging and avoid excessive logging, especially in hot paths. Never log credentials, tokens, or sensitive payloads.
* Keep authorization, certificate validation, encryption, and other security controls intact. Follow the focused security rules for the affected boundary.
* Keep side effects explicit and deterministic where practical; propagate cancellation and dispose owned resources correctly.
* Use narrow exception handling around the operation that can fail. Do not catch broadly merely to retry, continue with partial state, or convert failures into success.
* Avoid returning different error detail to unauthenticated callers when it would disclose whether protected accounts, records, or resources exist.
* Treat resource limits as part of safe error handling: cap request bodies, decompressed data, collection sizes, parser depth, and other attacker-controlled work.
