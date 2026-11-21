# Recovery Provenance Operational Observability

## Read-only timeline queries

`PluginRecoveryProvenanceQueryService` filters the append-only provenance
stream by package, deployment, actor, signer key, action, time range, and
exclusive sequence cursor. Results are ordered newest-first and use a
sequence-based continuation cursor. The service is read-only; a host adapter
may implement equivalent database-native filtering and keyset pagination for
large histories.

The in-memory/reference query implementation reads the store snapshot and
filters it in memory. It is not a substitute for indexed database queries,
tenant isolation, authorization, or snapshot-consistent pagination. Hosts must
authorize scope before constructing a query and must bind cursors to that scope
when exposing them externally.

## Audit snapshots and incident classification

`PluginRecoveryProvenanceAuditReporter` combines:
- full provenance-chain verification;
- external anchor verification and current/stale status;
- historical signing-key assessment for each signed event;
- event/signature counts and latest chain position;
- classified warning and critical incidents.

A stale but valid anchor is a warning, not a chain-integrity failure.
Missing anchors are reported separately from invalid anchors. Key revocation
after signing is distinguished from a key that was already revoked at signing
time. Incident severity is a neutral default classification, not a host
security policy or authorization decision.

The report is a point-in-time snapshot. It does not guarantee that all stores
were read under one distributed transaction or consistent cross-store
snapshot. Hosts needing stronger consistency should coordinate snapshot
versions or read at a shared audit watermark.

## Portable audit export

`PluginRecoveryProvenanceAuditReportCodec` exports a versioned JSON snapshot
containing verification summaries, key assessments, and incident records. It
does not export private keys, signatures' secret material, or raw package
contents. The report is not itself signed. Hosts should sign or externally
anchor exported reports when authenticity and tamper evidence are required.

## Security boundaries

- Query APIs do not provide authorization, tenant scoping, or access control.
- Audit generation is read-only and does not repair, append, revoke, or delete.
- Hosts supply durable stores, cryptographic providers, trust policy, and
  cross-store consistency guarantees.
- Incident classification is advisory; host policy determines response.
- The report codec is an interchange representation, not a canonical
  cryptographic format.
