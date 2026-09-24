# Network and SSRF security

* Use HTTPS and never disable certificate or TLS validation.
* Restrict inbound and outbound access to required ports, interfaces, hosts, and protocols.
* Treat user-controlled URLs as dangerous. Allowlist schemes and destinations, reject loopback, link-local, private, and cloud metadata ranges unless explicitly needed, and validate the resolved destination.
* Revalidate every redirect and DNS resolution to prevent redirects, rebinding, or mixed-address answers from bypassing destination restrictions. Disable automatic redirects when they cannot be safely checked.
* Set connection and overall timeouts, response-size limits, bounded concurrency, bounded retries, and cancellation for remote operations.
* Avoid forwarding ambient credentials, cookies, or authorization headers to a new host or redirect target.
* Use controlled egress where possible and avoid exposing internal error details or response bodies from remote services.
