# C# Async and Concurrency

Apply these rules when adding or changing asynchronous APIs, background work, or concurrent processing.

* Use asynchronous APIs for genuinely asynchronous I/O; do not wrap synchronous work in unnecessary tasks.
* Keep asynchronous operations async through the call chain. Avoid `.Result`, `.Wait()`, and other synchronous waits that can block threads or deadlock.
* Accept and propagate `CancellationToken` through work that can take meaningful time or be cancelled by its caller.
* Bound concurrency for large or unbounded workloads. Avoid creating a task per item or using uncontrolled `Task.WhenAll`; use an appropriate queue or concurrency limiter when work must be throttled.
* Use `ValueTask` only when profiling supports it and its usage contract is clear; otherwise prefer `Task`.
* Keep shared state safe under concurrent access and preserve cancellation and exception behavior when coordinating tasks. Prefer immutable messages or synchronization primitives with clear ownership over unsynchronized shared mutation.
* Avoid holding locks across `await`, blocking thread-pool threads, and starting background work whose lifetime is detached from its owner.
* For producer/consumer work, apply backpressure and bound buffered items so a fast producer cannot exhaust memory.
* Retry only transient failures, with bounded attempts and delay. Preserve idempotency and cancellation, and avoid multiplying retries across nested layers.
