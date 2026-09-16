## Security

* Treat all external input as untrusted.
* Never expose secrets, credentials or tokens in UI code.
* Do not store secrets in configuration files committed to source control.
* Avoid leaking sensitive information through logs, dialogs or exception messages.
* Validate file paths and external resources.
* Do not execute external processes or files without explicit validation.
* Avoid insecure deserialization.
* Do not weaken TLS, authentication or certificate validation.
* Prefer secure defaults.
* Never disable security controls for convenience.

## File and Process Access

* Validate file paths before use.
* Avoid assuming files or directories exist.
* Handle permissions and locked files gracefully.
* Avoid arbitrary shell execution.
* Quote and validate process arguments safely.
* Do not concatenate untrusted input into shell commands.
* Avoid elevated privileges unless explicitly required.
* Clean up temporary files when appropriate.

## Error Handling

* Handle expected errors explicitly.
* Do not swallow exceptions.
* Preserve useful exception context.
* Avoid showing raw technical exceptions directly to end users.
* Log enough information for diagnosis without exposing sensitive data.
* Keep user-facing error messages clear and actionable.
* Avoid using exceptions for normal control flow.
* Ensure background exceptions are observed.

## Logging

* Use structured logging.
* Avoid excessive logging on the UI thread.
* Do not log every property change or binding update.
* Never log secrets, tokens, credentials or sensitive user data.
* Include relevant context for operational failures.
* Avoid logging the same exception repeatedly at multiple layers.

## Validation

* Validate user input at the appropriate boundary.
* Keep validation logic out of XAML when it becomes complex.
* Prefer reusable validation rules or ViewModel validation for non-trivial cases.
* Display validation errors consistently.
* Do not rely on UI validation as a security boundary.
* Validate again at backend or domain boundaries when required.
* Preserve user input on recoverable errors.
