# C# Types and Collections

Apply these rules when designing type contracts, choosing collection shapes, or exposing data through APIs.

* Prefer strongly typed models over `object`, `dynamic`, loosely typed dictionaries, or string-based contracts.
* Write null-safe code: enable nullable reference types where supported, model nullability accurately, and check nullable values before dereferencing them. Avoid null-forgiving operators unless a nearby invariant proves the value cannot be null.
* Prefer concrete collection types for internal parameters, properties, and local APIs when the contract does not need abstraction.
* Expose collection interfaces such as `IReadOnlyList<T>`, `IEnumerable<T>`, `IDictionary<TKey, TValue>`, or `ICollection<T>` only when their capability is part of an intentional boundary or public contract.
* Choose collection types based on lookup, ordering, mutation, and iteration needs. Pre-size collections only when expected capacity is known and material.
* Avoid large mutable structs and direct exposure of mutable internal collections.
* Prefer immutable data and readonly state where practical, while preserving established API and serialization contracts.
