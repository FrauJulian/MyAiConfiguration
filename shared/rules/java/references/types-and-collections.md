# Java Types and Collections

Apply these rules when defining type contracts, choosing collections, or handling nullable values.

* Write null-safe code. State whether each boundary value may be absent, validate required values before dereferencing, and use the project's nullability annotations and analysis tools when available. Do not assume an annotation enforces runtime validation.
* Prefer non-null return values and empty collections for valid empty results. Use `Optional<T>` mainly for a return value that may have no result; do not return a null `Optional` or use it for fields and parameters by default.
* Distinguish a missing map key from a key mapped to null when the contract permits both. Do not use `get()` alone when that distinction matters.
* Keep public contracts strongly typed. Avoid raw types, unchecked casts, and stringly typed maps; document and narrowly suppress unavoidable generic warnings.
* Choose `List`, `Set`, `Map`, or a more specific type according to ordering, uniqueness, lookup, and mutation needs. Expose only the capabilities callers need; do not leak mutable internal collections.
* Distinguish an unmodifiable view from an independent copy. Make defensive copies at ownership boundaries when later mutation would violate the contract.
* Prefer immutable data for values with stable identity and ownership, while respecting framework and serialization requirements. Avoid unnecessary boxing and copies in measured hot paths.
