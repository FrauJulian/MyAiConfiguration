# Modern Java

Apply these rules when writing or reviewing Java code.

* Match the project's configured Java release, compiler flags, libraries, and style. Use newer language or library features only when that release supports them and they improve clarity.
* Prefer clear, immutable value types. Use records for transparent data carriers and sealed types when a closed set of variants is part of the domain; do not force these forms onto mutable entities or framework-bound types.
* Use pattern matching, switch expressions, and text blocks where supported and clearer than older forms. Keep control flow explicit; streams are not automatically clearer or faster than loops.
* Prefer local `var` only when the initializer makes the type obvious. Keep public APIs explicitly typed and avoid raw types and unchecked casts.
* Keep classes and methods focused, use descriptive names, and make state and side effects easy to see. Prefer composition and small interfaces at real boundaries over speculative abstractions.
* Use try-with-resources for `AutoCloseable` resources. Preserve interruption, exception causes, and precise failure context; do not swallow exceptions or use exceptions for ordinary control flow.
* Define nullability and mutability expectations at API boundaries. Prefer standard collection and `Optional` conventions without using `Optional` for fields or parameters by default.
* Avoid deprecated APIs and obsolete date/time or concurrency utilities when supported standard replacements fit the target release. Remove dead code and unused dependencies.
