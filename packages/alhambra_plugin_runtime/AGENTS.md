# Instructions for alhambra_plugin_runtime

This package implements host-side plugin registration, contribution composition,
lifecycle coordination, capability negotiation and recovery using contracts from
alhambra_plugin_api.

## Ownership
- Runtime code may orchestrate host-selected, compiled plugin instances.
- Keep product-specific policy, screens, routes and plugin bundles in the host application.
- Keep concrete database, network and identity integrations in optional adapter packages.
- Do not load or execute arbitrary downloaded Dart code.

## Lifecycle and safety
- Treat activation, deactivation, cleanup and recovery execution as side-effecting operations.
- Keep discovery, negotiation, planning and reconciliation read-only.
- Capability negotiation is not authorization; authorization remains a host/broker responsibility.
- Serialize conflicting operations and reject stale operation/revision data.
- Never automatically retry an ambiguous external side effect without an explicit idempotency and approval protocol.
- Preserve cleanup failures without hiding the primary failure; report partial outcomes structurally where possible.
- Do not infer external cleanup from an inactive registry entry.
- Persist only sanitized, allow-listed metadata. Never log secrets, credentials or arbitrary plugin payloads.

## Persistence and observability
- Keep core runtime contracts persistence-neutral.
- Clearly distinguish in-memory reference behavior from durable adapter guarantees.
- Document transaction boundaries, concurrency, retention, backpressure and recovery semantics.
- Outbox delivery is at-least-once unless a complete end-to-end protocol proves otherwise; require stable event IDs and consumer deduplication.
- Lease acknowledgements must be fenced by lease tokens.

## Testing
- Cover success, failure, partial side effects, cancellation, duplicate calls, stale writes and recovery.
- Use fake clocks, deterministic IDs and injected stores/publishers.
- Use adapter integration tests to prove database transactions and cross-process concurrency; in-memory tests cannot prove those properties.
- Update the public barrel export only for intentional public APIs.
