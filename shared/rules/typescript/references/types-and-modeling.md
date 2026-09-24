# TypeScript Types and Modeling

Apply these rules when defining TypeScript types, public function contracts, or domain data models.

* Prefer `strict: true`, precise types, and `unknown` for values whose shape has not been validated. Avoid `any`, broad assertions, and non-null assertions that hide uncertainty.
* Model variants with discriminated unions and use literal unions for constrained values. Make invalid states difficult to represent.
* Prefer `readonly` and immutable data when mutation is unnecessary. Use interfaces for implementation contracts or declaration merging; use type aliases for unions and compositions.
* Give exported APIs, callbacks, and non-trivial functions explicit contracts; rely on inference for simple local values where it keeps code clearer.
* Derive types from trusted existing contracts or generated sources instead of duplicating backend schemas manually. Regenerate generated contracts from their source rather than hand-editing them.
* Keep generic constraints meaningful and types readable. Avoid deep conditional or mapped types when a simpler model expresses the contract.
* Keep compile-time types aligned with runtime schemas. If a schema changes, update its inferred types and tests so the two do not silently drift.
* Avoid representing authorization state, validation success, or trusted input using a type assertion alone. Construct trusted values only after the required checks succeed.
