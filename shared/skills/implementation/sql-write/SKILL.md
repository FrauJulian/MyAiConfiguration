---
name: sql-write
description: Use when writing or modifying SQL queries, schema, database migrations, or data updates; account for dialect, compatibility, authorization, and data safety.
---

# SQL Write

Use when writing or changing SQL statements, schema definitions, or database migrations.

## Workflow

1. Identify the database engine and version, target schema, affected callers, and expected data shape. Inspect existing migrations and SQL style first.
2. Parameterize values and validate any dynamic identifiers against an allowlist. Preserve tenant boundaries and authorization filters in every query path.
3. For schema changes, consider existing rows, nullability, defaults, constraints, indexes, and deployment order. Prefer additive, backward-compatible steps when old and new application versions may overlap.
4. Use transactions and explicit rollback or recovery steps where supported and appropriate. Estimate affected rows before broad updates or deletes.
5. Do not execute destructive or production SQL without explicit authorization. A request to write SQL does not authorize running it against live data.
6. Verify syntax and behavior against the intended engine, then inspect query results, migration ordering, and relevant application tests.

Report the database dialect, files or migration changed, verification, and any operational prerequisite.
