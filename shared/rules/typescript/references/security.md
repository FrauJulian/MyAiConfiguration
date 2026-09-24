# TypeScript Security

Apply these rules when implementing or reviewing security-sensitive TypeScript code. Load the matching shared security rule for the affected API, identity, data, browser, file, network, cryptographic, or dependency boundary as well.

* Validate external data at runtime before using it in authorization decisions, database operations, filesystem access, or privileged actions. A type assertion is not validation.
* Enforce authentication, authorization, tenant scoping, and input validation on the server. Browser checks, hidden controls, route guards, and TypeScript types do not create a security boundary.
* Keep credentials and private keys on trusted servers. Never embed secrets in frontend bundles, source maps, browser storage, or public runtime configuration.
* Use cryptographically secure platform randomness for tokens and security-sensitive identifiers. Do not use `Math.random()` for secrets, session values, or authorization codes.
* Use parameterized database APIs and allowlists for dynamic identifiers. Avoid constructing SQL, shell commands, HTML, or other interpreted input by string concatenation.
* For server-side URL fetching, restrict protocols and destinations, validate redirects, and bound time, response size, and concurrency to reduce SSRF and resource-exhaustion risk.
* Use the framework's safe output encoding and preserve CSP, TLS, cookie, and CSRF protections. Do not disable these controls to make a request or test pass.
* Review untrusted object merges for prototype pollution, unsafe deserialization, and mass assignment. Copy only fields the caller is allowed to control.
* Review dependency additions and upgrades for source, package identity, install scripts, transitive risk, and lockfile changes.
