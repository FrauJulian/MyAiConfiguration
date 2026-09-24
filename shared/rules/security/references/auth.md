# Authentication and authorization security

* Use established authentication standards and password hashing; never store plaintext or reversibly encrypted passwords.
* Enforce authorization server-side for every sensitive operation and verify resource ownership and tenant boundaries.
* Use least-privilege roles, short-lived sessions or tokens where supported, and invalidate credentials after sensitive account changes.
* Validate token issuer, audience, signature, and expiry before trusting claims.
* Protect authentication and privileged actions against brute force and privilege escalation.
* Test unauthenticated, unauthorized, cross-user, and cross-tenant access paths.
