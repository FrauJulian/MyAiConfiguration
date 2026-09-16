## Performance

* Use `OnPush`.
* Use stable tracking in loops.
* Avoid unnecessary change detection triggers.
* Avoid repeated expensive template calculations.
* Avoid unnecessary subscriptions.
* Avoid unnecessary DOM rendering.
* Lazy-load large features and heavy dependencies where appropriate.
* Avoid large initial bundles.
* Avoid importing full libraries when only a small part is required.
* Avoid unnecessary deep cloning.
* Avoid unnecessary object and array recreation in hot paths.
* Keep state updates targeted.
* Avoid unnecessary global state updates.
* Measure bundle size and runtime performance before micro-optimizing.
* Prefer architectural improvements over template-level micro-optimizations.

## Performance Priority

Prioritize Angular performance work in this order:

* Application architecture
* Network and API behavior
* Bundle size and lazy loading
* State architecture
* Change detection
* Rendering and DOM complexity
* RxJS and subscription behavior
* Memory allocations
* CPU micro-optimizations

Never optimize based purely on assumptions.
