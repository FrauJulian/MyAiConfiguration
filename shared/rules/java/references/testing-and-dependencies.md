# Java Testing and Dependencies

Apply these rules when changing tests, build files, dependencies, or diagnostics.

* Write deterministic behavior-based tests for public contracts and failure paths. Avoid assertions tied to private call order, wall-clock timing, or uncontrolled external services.
* Test null and empty cases, malformed input, resource cleanup, interruption, and concurrency behavior when those risks are affected. Use integration tests for actual persistence, framework, or serialization boundaries.
* Keep production code testable through clear contracts and ownership. Do not add abstraction layers or production hooks solely for tests without a concrete need.
* Prefer the JDK and existing supported libraries when they solve the problem. Keep dependencies minimal, maintained, and compatible with the configured Java release.
* Respect the repository's Maven or Gradle dependency and plugin management. Review transitive changes, build plugins, and lockfiles; do not hand-edit generated dependency state.
* Treat compiler warnings and configured static-analysis findings as actionable. Suppress a diagnostic only with a specific reason and narrow scope.
* Run the focused tests and checks for the changed path; broaden verification when shared behavior, compatibility, or security is affected.
