# Java Safety and Error Handling

Apply these rules when handling external input, failures, resources, or logs.

* Validate size, range, format, and allowed values before expensive parsing, allocation, or side effects. Keep validation consistent with business and security constraints.
* Reject null where a value is required, with clear argument or boundary validation. Do not hide invalid state behind default values that change behavior.
* Use try-with-resources for owned `AutoCloseable` resources. Keep ownership explicit and do not close resources supplied by a caller unless the contract says so.
* Catch only failures the current layer can handle. Preserve exception causes and useful context; do not swallow failures, catch broadly to continue with partial state, or use exceptions for routine control flow.
* Preserve interruption and cancellation during error handling. Timeouts and retries need bounds and must not silently turn failure into success.
* Use structured logs where the project supports them. Never log credentials, tokens, personal data, or unbounded payloads; avoid excessive logging in hot paths.
* Return safe, consistent error information. Do not disclose protected resource existence or internal details to unauthorized callers.
