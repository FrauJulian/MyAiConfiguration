# Java Performance

Apply these rules when optimizing Java runtime, memory, or throughput.

* Measure a representative workload on the target JDK and deployment configuration before optimizing. Profile first; distinguish startup, steady-state latency, tail latency, throughput, allocation, GC, and memory costs.
* Prioritize algorithmic complexity, database and network round trips, I/O, contention, allocation and GC, then instruction-level work. Fix the dominant cost rather than tuning by intuition.
* Choose collections and algorithms for actual access patterns and data growth. Avoid repeated scans, needless sorting or copying, unbounded results, and N+1 data access.
* Stream or process data in bounded chunks when whole-input buffering can exhaust memory. Bound queues, caches, thread pools, and parallel work to the capacity of downstream systems.
* Reduce allocation in profiled hot paths. Avoid premature object pooling, custom caches, and low-level tricks; pooling can retain memory or leak mutable state.
* Use concurrency only when it improves measured end-to-end throughput or latency. Account for ordering, cancellation, backpressure, contention, and failure handling.
* Use JMH for JVM microbenchmarks when isolating small operations; prevent dead-code elimination and account for warmup, forks, and measurement variance. Use production-like profiling for system behavior.
* Re-run the same workload after a change and compare correctness, CPU, allocation, GC, memory, latency, and throughput. Keep the simplest implementation that meets the measured goal.
