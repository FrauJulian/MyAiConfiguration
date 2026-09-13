# Database and data security

* Use parameterized queries or ORM parameter binding; never concatenate untrusted input into SQL.
* Use least-privilege database accounts and protect connection strings.
* Scope tenant-owned queries explicitly and prevent cross-tenant cache, logging, and diagnostic leakage.
* Collect and retain only necessary sensitive data; encrypt it in transit and at rest where appropriate.
* Avoid raw database errors and use transactions where integrity requires atomicity.
