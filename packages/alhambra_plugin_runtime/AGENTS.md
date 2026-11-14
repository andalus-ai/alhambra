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

- Package verification must fail closed when payload integrity or required signature adapters are unavailable.
- Do not implement cryptographic primitives in the runtime; use injected, vetted adapters.
- Keep payload canonicalization explicit and consistent between packagers and verifiers.
- A valid signature does not by itself imply publisher trust; enforce publisher/key binding and host trust policy.
- Treat the in-memory trust store as a reference implementation, not production key management.

- Transactional installation requires an atomic create-only installed-record store; do not use an upsert-only store for install commits.
- Rollback must compare the candidate install record before removal so it cannot delete another concurrent installation.
- The default operation ID is instance-scoped; production hosts should inject globally unique operation IDs and enforce journal uniqueness.

- Installation recovery planning must be read-only and compare journal, filesystem provenance and installed metadata.
- Never infer destination ownership from a path string alone; require adapter-owned operation provenance.
- Recovery execution requires explicit operator identity, approval ID, fresh evidence and an atomic journal compare-and-set claim.
- If recovery side effects or outcome persistence are ambiguous, leave the operation unresolved for manual reconciliation; do not automatically repeat it.
- Recovery adapters must document and integration-test crash-safe idempotency for discard, rollback and finalization.
