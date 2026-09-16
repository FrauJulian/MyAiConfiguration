## Commands

* Prefer commands over click handlers for ViewModel-driven actions.
* Keep command execution focused.
* Avoid putting large workflows directly inside command implementations.
* Keep `CanExecute` logic cheap.
* Refresh command availability only when relevant state changes.
* Avoid command implementations with hidden side effects.
* Handle async commands safely.
* Prevent accidental duplicate execution when an async action must not run concurrently.
* Never use `async void` except for true event handlers.

## Async and Threading

* Keep async operations asynchronous throughout the call chain.
* Avoid `.Result`, `.Wait()` and other synchronous blocking of async work.
* Do not block the UI thread.
* Run I/O asynchronously.
* Move expensive CPU work off the UI thread only when necessary.
* Marshal UI updates back to the UI thread when required.
* Keep Dispatcher usage minimal and explicit.
* Do not use the Dispatcher to hide incorrect threading design.
* Support `CancellationToken` for cancellable long-running operations.
* Cancel obsolete work when views or selections change.
* Prevent race conditions caused by overlapping async operations.
* Handle exceptions from background operations explicitly.

## UI Thread

* Treat the UI thread as a scarce resource.
* Avoid expensive loops, parsing, serialization, database access or network calls on the UI thread.
* Avoid excessive Dispatcher invocations.
* Batch UI updates where practical.
* Do not update UI-bound collections excessively in tight loops.
* Avoid synchronous waits on background work.
* Keep rendering-related callbacks lightweight.

## Events

* Avoid unnecessary event subscriptions.
* Unsubscribe from long-lived publishers when required.
* Prevent memory leaks from event handlers.
* Prefer weak events where publisher lifetime significantly exceeds subscriber lifetime.
* Keep event handlers small.
* Do not use events as hidden global communication channels.
* Avoid excessive event chaining.
