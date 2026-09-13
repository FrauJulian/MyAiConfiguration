# Supply-chain security

* Keep dependencies minimal, maintained, and from verified sources; respect lockfiles and review identity and compatibility before adding or upgrading packages.
* Pin versions where appropriate and remove unused dependencies.
* Treat plugins, build scripts, CI actions, and generated artifacts as part of the attack surface.
* Use least privilege for build and deployment identities and never expose credentials in pipelines, logs, or artifacts.
