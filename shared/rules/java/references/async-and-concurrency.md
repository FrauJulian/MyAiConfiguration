# Java Async and Concurrency

Apply these rules when changing executors, threads, futures, background work, or shared state.

* Choose synchronous, asynchronous, platform-thread, or virtual-thread execution for the actual workload and target Java release. Virtual threads suit many blocking I/O tasks; they do not accelerate CPU work.
* Keep task lifetime owned by a request, service, or scoped executor. Close or shut down owned executors and handle completion, failure, timeout, and cancellation.
* Propagate interruption and cancellation. When catching `InterruptedException` without rethrowing it, restore the interrupt flag and stop work safely; do not turn cancellation into success.
* Bound queues, fan-out, and downstream calls. Virtual threads reduce thread cost but do not remove database, network, memory, or rate limits.
* Protect shared mutable state with clear ownership or suitable concurrency primitives. Do not assume `volatile` makes compound actions atomic.
* Avoid blocking joins inside unrelated executor tasks when they can exhaust a bounded pool. Use `CompletableFuture` or parallel streams only when their execution context and failure behavior are understood.
* Keep retries limited to transient failures, with bounded attempts and delay. Preserve idempotency and avoid retry multiplication across layers.
* Use preview concurrency APIs only when the project explicitly enables them for its target release.
