# Authentication and authorization security

* Use established authentication standards and password hashing; never store plaintext or reversibly encrypted passwords.
* Use a maintained password-hashing scheme configured for the deployment environment. Never create password schemes or reduce work factors merely to improve latency.
* Enforce authorization server-side for every sensitive operation and verify resource ownership and tenant boundaries.
* Deny by default and check authorization on every request, including background jobs and alternate API paths. Do not trust role or identity values supplied by clients.
* Use least-privilege roles, short-lived sessions or tokens, secure renewal and revocation, and invalidate credentials after password, recovery, or privilege changes.
* Validate token algorithm, issuer, audience, signature, expiry, and any required not-before or key identifier claims before trusting it. Reject unexpected algorithms and malformed claims.
* Protect login, recovery, reset, MFA, and privileged actions against brute force, enumeration, replay, CSRF, and privilege escalation.
* Store session identifiers securely; rotate them after authentication or privilege changes and invalidate them on logout or account recovery.
* Test unauthenticated, unauthorized, cross-user, cross-tenant, expired-token, revoked-session, and recovery-flow paths.
