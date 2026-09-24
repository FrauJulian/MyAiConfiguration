---
name: performance-review
description: Use when evaluating a code change for likely latency, throughput, memory, allocation, or resource-use regressions; distinguish measurements from estimates.
---

# Performance Review

Use when reviewing a change for meaningful latency, throughput, memory, or resource-use risk.

## Review

1. Identify the changed execution paths and their expected frequency, input size, and concurrency.
2. Trace expensive work such as repeated I/O, network calls, database round trips, allocations, serialization, locks, and scans.
3. Estimate algorithmic cost and resource growth with realistic data sizes. Separate measured results from reasoned estimates.
4. Check whether a proposed cache, parallelism, or batching change preserves invalidation, ordering, cancellation, and failure behavior.
5. Recommend a benchmark or profiler only when it can answer a concrete uncertainty. Avoid micro-optimizations without a plausible user impact.

Report the affected path, evidence, likely impact, and smallest useful correction or measurement. Do not present theoretical concerns as confirmed regressions.
