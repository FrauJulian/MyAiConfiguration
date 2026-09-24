---
name: integration-test-write
description: Use when adding or changing tests for behavior across a real boundary, such as an API and database, filesystem command, or cooperating services. Not for isolated unit behavior.
---

# Integration Test Write

Use when verifying behavior across a real application boundary, such as an API and database, a command and filesystem, or cooperating services.

## Workflow

1. Name the boundary under test and the production path the test must exercise. Keep unit-level details covered by unit tests.
2. Reuse the repository's integration-test setup. Start only the services and data stores required for this behavior.
3. Prepare minimal isolated data and control external inputs. Prevent test runs from touching user data, shared environments, or live services.
4. Cover a successful interaction and the failure or rejection path that matters to the change. Include transaction, retry, or cleanup behavior only when it is part of the contract.
5. Assert persisted or externally observable outcomes, including relevant status, response, and side effects.
6. Clean up created resources even when assertions fail. Make repeated runs safe and independent.
7. Run the focused integration test and report required services, results, and any unavailable environment.

Avoid turning an integration test into a full end-to-end suite when a narrower boundary proves the contract.
