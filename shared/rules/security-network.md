# Network and SSRF security

* Use HTTPS and never disable certificate or TLS validation.
* Restrict inbound and outbound access to required ports, interfaces, hosts, and protocols.
* Treat user-controlled URLs as dangerous: allowlist schemes and hosts, block localhost, metadata, and internal ranges, and revalidate redirects.
* Set timeouts, response-size limits, bounded retries, and cancellation for remote operations.
