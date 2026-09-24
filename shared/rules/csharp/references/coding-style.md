# C# Coding Style

Apply these rules when editing C# syntax, class structure, and everyday code organization.

* Follow current C# and .NET conventions and the style already used in the project.
* Prefer direct, readable code over clever control flow, hidden magic, or outdated verbosity.
* Keep classes, methods, and responsibilities focused. Use descriptive names and established domain terms; avoid unexplained abbreviations.
* Prefer composition over inheritance. Use inheritance only for a real substitutable contract, and seal types when extension is not intended.
* Avoid unnecessary wrappers, abstractions, reflection, runtime type checks, and global mutable state.
* Prefer immutable or readonly state when it simplifies ownership and reduces accidental mutation.
* Keep side effects visible. Make behavior deterministic and easy to test where practical.
* Add comments or API documentation only for non-obvious decisions, public contracts, or documented project requirements.
* Remove dead code instead of leaving commented-out implementations.
