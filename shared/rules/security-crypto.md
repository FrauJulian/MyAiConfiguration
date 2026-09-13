# Cryptography and secrets security

* Never implement custom cryptographic primitives or use obsolete algorithms.
* Use established libraries, authenticated encryption, secure randomness, and verified signatures and certificates.
* Treat tokens, private keys, connection strings, and credentials as secrets; keep them out of source, URLs, command lines, logs, fixtures, and frontend code.
* Use environment-appropriate secret storage, separate environments, and rotate compromised credentials.
