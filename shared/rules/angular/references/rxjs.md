## RxJS

* Use RxJS for asynchronous streams, events and complex reactive flows.
* Do not use RxJS when simple synchronous signals are sufficient.
* Prefer declarative observable pipelines.
* Avoid nested `subscribe`.
* Avoid manual subscriptions where `async`, signals or framework helpers are sufficient.
* Prefer `takeUntilDestroyed` or equivalent Angular lifecycle integration for manual subscriptions.
* Always consider subscription lifetime.
* Avoid memory leaks from unmanaged subscriptions.
* Use the correct flattening operator for the required semantics.
* Do not use `switchMap`, `mergeMap`, `concatMap` or `exhaustMap` interchangeably.
* Avoid unnecessary `Subject` usage.
* Prefer exposing observables instead of exposing mutable subjects.
* Prefer `BehaviorSubject` only when a current value is actually required.
* Avoid excessive observable chains for simple state.
* Avoid converting repeatedly between signals and observables without need.
