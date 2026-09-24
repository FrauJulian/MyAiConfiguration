# Database and data security

* Use parameterized queries or ORM parameter binding; never concatenate untrusted input into SQL.
* Parameterize values in every query path, including raw SQL and stored procedures. Allowlist dynamic table names, columns, and sort directions.
* Use least-privilege database identities, separate application and migration privileges, and protect connection strings and backup credentials.
* Scope tenant- and user-owned reads, writes, joins, aggregates, background tasks, and cache keys explicitly. Do not rely on a caller having applied a filter elsewhere.
* Collect and retain only necessary sensitive data. Set retention and deletion behavior and protect backups, exports, replicas, logs, and analytics copies.
* Encrypt sensitive data in transit and at rest where appropriate; keep key access separate from database access.
* Use transactions and suitable constraints where integrity requires atomicity. Check concurrency and isolation around security-sensitive state changes.
* Avoid raw database errors and sensitive query parameters in responses, logs, traces, and metrics.
* Test injection, cross-tenant access, unauthorized mutation, stale updates, and cache isolation within the approved scope.
