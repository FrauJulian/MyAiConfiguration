# Supply-chain security

* Keep dependencies minimal, maintained, and from verified sources; respect lockfiles and review identity and compatibility before adding or upgrading packages.
* Verify package identity, source, maintainer, release history, transitive dependencies, and install-time behavior. Treat typosquats and unexpected ownership changes as risks.
* Pin or constrain versions according to project policy, commit lockfiles, and remove unused dependencies. Review lockfile changes instead of hand-editing generated entries.
* Review dependency and build-tool updates for breaking behavior and security advisories; upgrade deliberately and verify the resulting artifact.
* Treat plugins, build scripts, CI actions, compiler plugins, generated artifacts, and caches as part of the attack surface. Pin CI actions to reviewed immutable revisions where supported.
* Use least-privilege build and deployment identities. Separate untrusted pull-request jobs from secret-bearing jobs and protect release credentials from untrusted code.
* Never expose credentials in pipelines, logs, caches, artifacts, command output, or generated packages. Limit secret lifetime and scope.
* Verify artifact provenance and integrity before release or installation; avoid downloading and executing unverified content dynamically.
