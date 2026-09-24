# Cryptography and secrets security

* Never implement custom cryptographic primitives or use obsolete algorithms.
* Use maintained platform cryptography with authenticated encryption, secure randomness, and verified signatures and certificates. Use safe, documented parameter choices rather than inventing formats or defaults.
* Keep key generation, storage, access, rotation, revocation, and backup separate from application data where practical. Restrict each key to its intended purpose.
* Treat tokens, private keys, connection strings, and credentials as secrets; keep them out of source, URLs, command lines, logs, fixtures, error messages, and frontend code.
* Use environment-appropriate secret storage, separate environments, and rotate compromised or overexposed credentials. Do not silently fall back to a weaker key or algorithm when configuration is missing.
* Compare secret-derived values with established constant-time APIs when the comparison is security-sensitive.
* Do not log plaintext or retain decrypted sensitive data longer than required. Apply secure disposal only where the runtime and data type provide meaningful guarantees.
