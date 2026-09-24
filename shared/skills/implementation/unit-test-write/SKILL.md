---
name: unit-test-write
description: Use when adding or changing tests for one isolated function, component, or decision. Use integration-test-write when behavior must cross an application or service boundary.
---

# Unit Test Write

Use when adding or updating tests for one isolated function, component, or decision.

## Workflow

1. Read the requirement and implementation. Identify the observable result that defines success and the boundary conditions most likely to fail.
2. Follow the repository's existing test framework, naming, setup, and assertion style. Avoid new dependencies or fixtures when a small test can express the behavior.
3. Cover the normal case and the smallest meaningful set of boundary or failure cases. Include a regression case for a reported defect.
4. Assert public behavior and useful error outcomes rather than private call order, incidental wording, or internal data layout.
5. Keep each test deterministic. Control time, randomness, filesystem state, and external services when they affect the result.
6. Run the focused test and report its result. Broaden verification only when shared behavior or connected components are affected.

Do not add tests that duplicate existing coverage or require production code to expose test-only hooks without a clear reason.
