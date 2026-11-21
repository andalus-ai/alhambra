# Recovery Provenance Production Readiness

## Adapter conformance

The test-only package exposes PluginRecoveryProvenanceConformanceSuite with
separate checks for:

- provenance event stores: concurrent append-if-head-matches, read-after-write,
  duplicate event ID rejection, and stale-head rejection;
- signing-key history stores: concurrent sequence append, read-after-write, and
  duplicate event ID rejection;
- external anchor stores: concurrent append, read-after-write, and chain identity
  enforcement.

Each invocation requires fresh disposable stores and a unique run ID. These
contracts are append-only and intentionally do not expose delete operations.
The suite performs writes and does not clean up records. Run it against an
isolated namespace or disposable database/schema.

The checks run concurrent futures in one process. They are useful behavioral
conformance checks but do not prove cross-process or cross-host transaction
atomicity. Production adapters must add integration tests using independent
database connections or worker processes, plus durability tests across process
termination and storage restart. They should also test backup/restore and
replication lag behavior.

## External provenance checkpoint anchors

A provenance hash chain detects edits within the observed chain, but a party
able to rewrite the entire store can rebuild the chain. External checkpoint
anchors provide independently retained signed observations of a chain head.

PluginRecoveryProvenanceAnchorPublisher creates a signed checkpoint containing:

- stable chain ID and monotonic anchor sequence;
- provenance event sequence and head event digest/algorithm;
- UTC anchoring timestamp;
- signer key ID and signature algorithm.

The payload is domain-separated. The host supplies the signing implementation
and stores anchors in a separately protected append-only
PluginRecoveryProvenanceAnchorStore. A production anchor store must implement
append-if-sequence-matches atomically across processes and must not permit
updates, deletions, truncation, or rollback.

PluginRecoveryProvenanceAnchorVerifier checks anchor sequence continuity,
chain identity, strictly increasing anchored provenance positions, timestamp
ordering, existence of each referenced event, digest equality, and detached
signatures. Its report distinguishes a valid chain with a current anchor from
a valid chain with an unanchored tail. A valid but stale anchor is not proof
that the latest provenance events are externally protected.

Hosts should run the full PluginRecoveryProvenanceVerifier before publishing
a new anchor. The publisher intentionally does not assume or invoke a specific
provenance verifier or trust policy. The verifier for anchors checks the
referenced event digest and anchor signature; it does not itself re-run every
provenance event signature or digest check. Run both verifiers as part of an
audit.

## Recommended production deployment

1. Use a durable provenance store with atomic append-if-head-matches and
   independent worker concurrency tests.
2. Use a separate anchor store/account or independently controlled audit
   service, not the same mutable database and credentials as the provenance
   store.
3. Publish anchors at an operationally appropriate interval and after
   high-value events. More frequent anchors reduce the maximum unanchored tail.
4. Retain signer key IDs and signing-key history; apply the host trust policy
   when verifying old signatures.
5. Periodically export anchor records to immutable/offline retention or a
   transparency service.
6. Alert on invalid anchors, missing predecessors, stale anchors, and a chain
   that is unexpectedly shorter than its latest external checkpoint.
7. Test disaster recovery by restoring a provenance database snapshot and
   comparing it with independently retained anchors.

## Security boundaries

- Alhambra supplies contracts and reference in-memory stores only. It does not
  ship a production database adapter, KMS/HSM integration, or signing key.
- The anchor signing key and anchor store should have separate access controls
  from the provenance writer. Otherwise one compromised principal may rewrite
  both the chain and its checkpoints.
- A valid anchor proves that a signer attested to a particular chain head. It
  does not prove the events are truthful, complete, authorized, or correctly
  timestamped.
- A valid but stale anchor means new events have not yet been externally
  checkpointed; it is not automatically a chain-integrity failure.
- The anchor verifier checks signatures cryptographically through the supplied
  verifier but does not decide whether a key is trusted, revoked, or acceptable
  under current policy. Hosts must combine it with signing-key history and
  package trust policy.
- No automatic anchoring schedule, external transparency log, database
  migration, key rotation, or incident response is included.
