## Collections

* Use `ObservableCollection<T>` only when collection change notifications are required.
* Do not use `ObservableCollection<T>` as a general-purpose collection.
* Use `List<T>` or other suitable collections for non-observable internal data.
* Avoid replacing entire observable collections when incremental updates are sufficient.
* Avoid thousands of individual collection notifications when a bulk update is more appropriate.
* Keep collection mutations on the correct thread.
* Avoid exposing mutable internal collections unnecessarily.
* Prefer read-only views where consumers should not modify data.

## XAML

* Keep XAML readable and focused.
* Avoid excessively large view files.
* Split complex views into focused controls when it improves maintainability.
* Use resources for repeated values and styles.
* Avoid magic numbers in XAML.
* Keep styles and templates consistent.
* Avoid excessive inline styling.
* Prefer reusable resources over duplicated markup.
* Avoid deeply nested panels.
* Keep visual trees as shallow as practical.
* Use semantic control choices.
* Avoid unnecessary containers.
* Do not overuse triggers when simpler state representation is possible.
* Keep templates understandable.
* Avoid XAML tricks that make behavior hard to discover.

## Layout

* Prefer `Grid` for structured layouts.
* Use `StackPanel` only where its layout behavior is actually appropriate.
* Avoid unnecessary nested panels.
* Avoid fixed sizes unless the design requires them.
* Prefer responsive sizing with `Auto` and `*`.
* Avoid layout configurations that cause excessive measure/arrange passes.
* Be careful with large visual trees inside scrolling containers.
* Avoid disabling virtualization accidentally.

## Virtualization

* Keep UI virtualization enabled for large collections.
* Do not use container layouts that disable virtualization without a reason.
* Avoid wrapping large virtualized item lists in additional scrolling containers.
* Use virtualizing panels where appropriate.
* Verify virtualization when displaying large data sets.
* Avoid rendering thousands of controls simultaneously.
* Prefer paging, incremental loading or virtualization for very large data sets.
