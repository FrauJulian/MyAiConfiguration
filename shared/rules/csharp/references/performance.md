# C# Performance

Apply these rules when optimizing code or reviewing runtime and resource costs.

* Establish a representative baseline before changing code. Measure the affected workload, input size, concurrency, and environment; distinguish average latency from tail latency and throughput.
* Find the dominant cost before optimizing: architecture, database access, network and I/O, algorithms, concurrency, allocations and GC, then CPU-level work.
* Choose collections and algorithms for actual access patterns. Check asymptotic cost and data growth; avoid repeated scans, unnecessary sorting, copies, and unbounded result sets.
* Keep data close to where it is processed. Filter and project in the database, avoid N+1 queries, bound page sizes, and avoid materializing rows or columns the caller does not use.
* Stream large inputs and outputs when buffering the whole value would waste memory. Bound queues, batches, and parallel work to match downstream capacity.
* Reduce allocations in measured hot paths: avoid repeated string construction, iterator/delegate capture, boxing, and collection resizing when profiling identifies them as material costs.
* Consider pooling only for expensive reusable objects with clear ownership and reset rules. Pooling can retain memory or leak state between users; measure it and cap retained capacity.
* Use `Span<T>`, `ValueTask`, preallocation, or specialized low-level APIs only when their benefit is demonstrated and they preserve readable, safe ownership.
* Cache only when repeated work is measurable and the key, lifetime, size bound, invalidation, and sensitive-data handling are explicit.
* After an optimization, run the same workload and compare correctness, allocations, GC, CPU, latency, and throughput against the baseline. Keep the simplest change that meets the target.
