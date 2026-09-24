# TypeScript Async Work and Resources

Apply these rules when implementing promises, I/O, streams, subscriptions, timers, or other long-lived work.

* Handle every rejected promise. Do not leave floating promises; for intentional fire-and-forget work, attach error handling and make its owner and lifetime explicit.
* Use `await` when sequencing or error handling depends on completion. Use `Promise.all` only for independent, bounded work that can safely run together.
* Limit concurrency for large workloads with a queue or limiter. Apply backpressure to streams and producer/consumer flows instead of buffering without a bound.
* Support cancellation with `AbortSignal` when callers need to stop I/O or long-running work. Propagate it through nested calls and release resources when cancellation occurs.
* Avoid synchronous blocking and long CPU-bound work on the Node.js event loop or browser main thread. Move substantial CPU work to a worker or split it into bounded tasks when measurements justify it.
* Remove event listeners, timers, subscriptions, streams, and abort handlers when their owner is done. Avoid retaining closures or resources beyond their intended lifetime.
* Keep shared mutable state safe and deterministic when asynchronous operations can overlap. Prevent stale responses from overwriting newer state when request ordering matters.
* Retry only failures known to be transient, with bounded attempts and delay. Preserve idempotency and cancellation; avoid multiplying retries across layers.
