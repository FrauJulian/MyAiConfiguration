# TypeScript Performance

Apply these rules when optimizing TypeScript runtime, rendering, or memory use.

* Establish a baseline using representative data, devices, concurrency, and runtime versions. Measure the user-visible path and its latency distribution, throughput, memory, and CPU cost as relevant.
* Prioritize architecture, network and API usage, database access, algorithms, rendering, concurrency, allocations, then CPU micro-optimizations. Confirm that the suspected layer dominates before changing it.
* Avoid quadratic scans and repeated full collection passes for large inputs. Choose `Map`, `Set`, or an indexed lookup when it reduces measured repeated work and its memory cost is acceptable.
* Avoid unnecessary object spreading, intermediate arrays, copies, deep clones, and serialization in hot paths. Do not replace clear code with opaque loops without measured benefit.
* In browsers, reduce unnecessary component updates and DOM work; virtualize large lists when rendering all rows is costly. Avoid memoization that adds stale-state or invalidation bugs.
* In Node.js, keep CPU-heavy synchronous work from blocking the event loop. Stream large payloads and bound queues, buffers, and concurrent requests.
* Prefer platform APIs over custom low-level code or dependencies. Use `structuredClone` only when a deep clone is required and its data constraints are met.
* Cache only repeated measurable work, with bounded size, explicit keys, expiry/invalidation, and safe treatment of user- or tenant-specific data.
* Do not add batching or parallelism without preserving ordering, cancellation, rate limits, and failure behavior. Measure end-to-end results after the change.
