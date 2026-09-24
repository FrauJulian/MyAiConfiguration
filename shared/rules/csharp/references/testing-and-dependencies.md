# C# Testing and Dependencies

Apply these rules when changing tests, package references, analyzers, or build diagnostics.

* Write deterministic behavior-based tests. Avoid coupling assertions to private call order, implementation details, current time, or uncontrolled external services.
* Make code testable through clear contracts and dependencies; do not add production hooks or abstractions solely for tests without a concrete need.
* Prefer the .NET BCL and existing supported packages over new libraries when they solve the problem adequately.
* Keep dependencies minimal, maintained, compatible, and updated through the repository's normal package-management process.
* Treat compiler, analyzer, and nullable warnings seriously. Suppress a diagnostic only for a specific, documented reason and narrow the suppression to the affected code.
* Run focused tests and analyzers for the changed path; broaden verification when shared behavior or compatibility could be affected.
