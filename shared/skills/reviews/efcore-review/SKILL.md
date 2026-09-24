---
name: efcore-review
description: Use when reviewing Entity Framework Core LINQ queries, models, migrations, or persistence behavior for correctness, provider behavior, performance, and data-scope risks.
---

# EF Core Review

Use when reviewing Entity Framework Core queries, model changes, migrations, or persistence behavior.

## Review

- Check whether LINQ translates as intended for the configured provider and whether filters are applied before materialization.
- Look for N+1 access, unbounded result sets, unnecessary tracking, duplicate queries, and over-fetching. Verify eager or explicit loading matches the data needed.
- Review relationship configuration, delete behavior, keys, nullability, indexes, and concurrency tokens against the domain invariants.
- Check migration ordering, generated SQL, data backfills, rollback limits, and compatibility while old and new application versions may coexist.
- Inspect transaction scope, isolation, retry behavior, cancellation, and handling of concurrency conflicts where applicable.
- Ensure sensitive or tenant-scoped rows cannot be read or changed outside the authorized scope.

Report findings with the query or migration path, runtime or data impact, and relevant provider-aware verification. Avoid recommending indexes or caching without evidence of a query need.
