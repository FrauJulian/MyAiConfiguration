# Java Coding Style

Apply these rules when editing Java syntax, class structure, and everyday code organization.

* Match the project's Java release, style, and framework conventions. Use newer syntax only when supported and clearer.
* Prefer direct control flow and descriptive domain names. Use streams when they clarify a transformation; loops are often clearer for stateful work or error handling.
* Use local `var` only when the initializer makes the type obvious. Keep public contracts explicitly typed.
* Use records for transparent immutable carriers and sealed types for genuinely closed variants when the target release supports them. Do not force them onto mutable entities or framework-managed types.
* Prefer composition and focused classes over inheritance, broad base classes, reflection, wrappers, global mutable state, or speculative interfaces.
* Make ownership, mutation, and side effects visible. Use `final` where it clarifies invariants; do not add it mechanically to every local variable.
* Prefer supported `java.time` APIs and standard library facilities over obsolete APIs or custom helpers when they fit the contract.
* Remove dead code. Add comments only for non-obvious decisions or public contracts that code cannot express clearly.
