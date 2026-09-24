---
name: api-review
description: Use when reviewing HTTP or RPC endpoint, request handling, serialization, schema, or API contract changes for correctness, security, and client compatibility.
---

# API Review

Use when reviewing an HTTP or RPC API contract, endpoint, serializer, or request-handling change.

## Review

- Trace the request from routing through authentication, authorization, validation, business logic, and persistence. Check tenant or resource ownership at the point data is accessed.
- Compare request and response schemas, status codes, error shapes, pagination, identifiers, and nullability with existing consumers and published contracts.
- Check malformed, missing, oversized, duplicated, and unauthorized input where relevant. Ensure validation errors do not disclose sensitive data.
- Consider compatibility for older clients, retries, idempotency, concurrency, and versioning when those affect the endpoint.
- Review serialization defaults, content types, limits, and generated client or schema updates.
- Confirm documentation and examples match actual behavior.

## Findings

Report concrete contract breaks, security weaknesses, or incorrect behavior first. Give location, triggering request, impact on consumers, and a practical correction. Distinguish optional design suggestions from defects.
