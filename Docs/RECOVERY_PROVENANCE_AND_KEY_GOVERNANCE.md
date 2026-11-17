# Recovery Provenance and Signing-Key Governance

## Purpose

Portable archive digests and signatures establish integrity and signer authenticity
for a package at a point in time. They do not provide an operational history of
where a package was exported, imported, restored, migrated, or verified. This
extension defines host-neutral records for that history and append-only signing
key lifecycle metadata.

The contracts are persistence- and cryptography-neutral. Hosts provide durable
stores, digest providers, signature services, identity, authorization, and audit
policy.

## Recovery provenance chain

PluginRecoveryProvenanceEvent records:

- stable event ID and monotonic chain sequence;
- action (packageCreated, exported, imported, restored, migrated, or verified);
- UTC event timestamp, source deployment ID, and optional actor ID;
- package ID, package digest algorithm, and package digest;
- optional signer key ID, signature algorithm, and detached signature;
- predecessor event digest and this event's digest.

PluginRecoveryProvenanceAppender reads the current head, constructs the next
event, computes its digest using the host-supplied digest provider, and
optionally signs a domain-separated payload using the host signer. It commits
with appendIfHeadMatches. A concurrent writer that changes the head causes
the append to fail; callers must inspect the new head and create a fresh event
rather than silently reusing a stale sequence.

PluginRecoveryProvenanceVerifier performs a read-only walk of the chain. It
checks schema version, sequence continuity, unique event IDs, predecessor
links, non-decreasing event timestamps, event digests, and signatures when
present. Hosts may require every event to be signed. The verifier reports the
first failing event and the number of preceding verified events.

The in-memory store is a test/reference implementation only. Production
adapters must guarantee append-if-head-matches atomically across all processes
and must protect the log against update, deletion, rollback, and unauthorized
truncation. A hash chain alone does not prevent an attacker who can rewrite the
entire chain; periodically anchor or externally sign chain heads in a separately
protected audit system.

## Signing-key lifecycle history

PluginRecoverySigningKeyLifecycleEvent captures activation, rotation,
retirement, and revocation events, including key ID, algorithm, principal,
timestamps, optional validity bounds, successor key ID, and reason code.
PluginRecoverySigningKeyHistoryStore is an append-only host persistence
contract with a sequence guard. The in-memory implementation is for tests and
ephemeral hosts only.

PluginRecoverySigningKeyHistoryInspector.assess() separates two questions:

- Was the key valid at the package's signing time?
- Is the key currently recorded as revoked?

A signature created before a later revocation can therefore be historically
valid while the key is currently revoked. A signature at or after the
revocation timestamp is reported as revoked at signing time. This is historical
metadata assessment, not a complete trust decision: hosts must also apply
current policy, algorithm allow-lists, principal binding, certificate/key
material validation, and any required external timestamp or transparency
evidence.

Rotation is represented by an explicit successor key ID on the old key's
rotation/retirement event and a separate activation event for the successor.
Alhambra does not generate keys, copy key material, change trust stores, or
decide whether old signatures remain acceptable after rotation or revocation.

## Operational integration

For each package lifecycle operation, hosts should append provenance only after
the operation's outcome is known and include the package identity and digest
that were actually processed. Do not record a successful import/restore merely
because preview or signature verification succeeded. Use distinct events for
verification and import.

Recommended event flow:

1. Package created or exported by deployment A.
2. Package signature verified by deployment B.
3. Package imported into B's archive store.
4. Archive record restored into B's operational job store, if explicitly
   authorized.
5. Archive migrated to a new format, with source and destination package
   identities captured in host audit metadata.

The event schema currently records one package identity per event. For a
migration, hosts should emit a source verification event and a destination
migration event, correlating them through their external audit/correlation
system until a future schema adds explicit source/destination package fields.

## Security and limitations

- The digest and signature providers are host supplied. Use vetted cryptographic
  algorithms and protected KMS/HSM-backed signing keys.
- The in-memory stores are not durable, multi-process, or tamper-proof.
- appendIfHeadMatches and key-history sequence checks must be implemented
  with durable atomic operations by production adapters.
- The provenance verifier validates the stored event chain; it cannot prove
  that a host honestly recorded every operation or prevent full-chain rollback
  without an external anchor.
- The key history inspector evaluates supplied lifecycle events. It does not
  validate the event log's authenticity or completeness and must not replace
  the host's trust policy.
- Historical validity is not equivalent to current acceptance. Hosts decide
  whether to accept signatures from keys that have since been retired or
  revoked, and whether trusted timestamp evidence is required.
- No automatic key rotation, revocation propagation, re-signing, package
  re-import, recovery execution, or audit export is performed.
