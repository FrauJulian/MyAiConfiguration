# API security

* Authenticate and authorize protected endpoints; validate every request payload and identifier.
* Bound request and response sizes, pagination, query results, and expensive operations.
* Apply rate limits where abuse is plausible and keep administrative endpoints separately protected.
* Return only authorized data and never expose stack traces, internal models, or implementation details in API errors.
* Prefer explicit DTOs and schemas over deserializing arbitrary types or executable objects.
