# C# Types and Collections

Apply these rules when designing type contracts, choosing collection shapes, or exposing data through APIs.

* Prefer strongly typed models over `object`, `dynamic`, loosely typed dictionaries, or string-based contracts.
* Prefer concrete collection types for internal parameters, properties, and local APIs when the contract does not need abstraction.
* Expose collection interfaces such as `IReadOnlyList<T>`, `IEnumerable<T>`, `IDictionary<TKey, TValue>`, or `ICollection<T>` only when their capability is part of an intentional boundary or public contract.
* Choose collection types based on lookup, ordering, mutation, and iteration needs. Pre-size collections only when expected capacity is known and material.
* Avoid large mutable structs and direct exposure of mutable internal collections.
* Prefer immutable data where practical, while preserving established API and serialization contracts.
* Use `Span<T>` and related low-level types only when the performance rule's measurement justifies their lifetime and ownership constraints.
