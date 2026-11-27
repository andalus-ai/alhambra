# Plugin Revocation Access-Audit Hash Chain

## Purpose and guarantees

The SQLite and PostgreSQL access-audit adapters optionally expose
`PluginRevocationAccessAuditChainStore`. Their append operation now writes the
audit record, per-scope chain entry, and per-scope chain head in one database
transaction.

The chain provides tamper evidence for covered rows. It is not a digital
signature, write-once medium, or protection against a privileged database
operator who can rewrite the audit table, chain entries, and head together.

## Data model

Each scope has an independent chain:

- Genesis hash: 64 zero characters.
- Sequence: starts at 1 and increases by one for each appended audit event in
  that scope.
- Canonical payload: JSON array version 1, containing actor, scope, decision,
  denial code, UTC occurrence timestamp, resource, page size, continuation
  flag, and query fingerprint in a fixed order.
- Entry hash: SHA-256 of UTF-8 bytes of
  `previousHash + "\n" + canonicalPayload`.
- Chain head: the latest sequence and entry hash for the scope.

The chain entry references the audit row. Verification recomputes the canonical
payload from the audit row, checks the previous-hash link and entry hash,
checks sequence continuity, checks the stored head, and checks that every audit
row in the scope has exactly one chain entry. This also detects rows inserted
directly into the audit table without using the adapter append API.

## Atomic append and concurrency

SQLite uses `BEGIN IMMEDIATE` to serialize writers and atomically insert the
audit row, chain entry, and head update.

PostgreSQL uses a transaction-scoped advisory lock derived from the scope ID,
then inserts the audit row, reads the current head, inserts the chain entry,
and updates the head in the same transaction. A failed operation rolls back
all three writes. The lock is scoped to one tenant/workspace scope, so
independent scopes can append concurrently.

## Migration and existing data

On first chain-table creation, the adapters backfill pre-existing access-audit
rows in stable `audit_id` order within each scope. This establishes an initial
chain for the historical rows already present at migration time. Subsequent
migrations do not silently repair an existing chain.

All new writes must go through the adapter's `append` method. Direct inserts
into the audit table are detected as unchained rows during verification.
Direct updates or deletes to audit rows, chain entries, or chain heads should
be denied to the application role.

## Verification

Both durable adapters expose:

```dart
final result = await auditStore.verifyAccessAuditChain(
  scopeId: requestedScope,
);

if (!result.valid) {
  // Alert, preserve evidence, and stop treating the audit trail as trusted.
  reportIntegrityFailure(
    scopeId: result.scopeId,
    failedSequence: result.failedSequence,
  );
}
```

Verification is scoped and currently scans the complete chain for that scope.
For very large audit trails, schedule verification as a background integrity
job and consider a future checkpoint-based incremental verifier.

A successful result means the stored chain is internally consistent with the
covered audit rows and head at verification time. It does not prove that no
privileged actor rewrote the complete database state before verification.

## Stronger protection and operations

For protection against privileged database rewrites:

1. Periodically export each scope's sequence and head hash to a separately
   controlled system.
2. Sign those checkpoints with a host-managed signing key.
3. Store signed checkpoints in immutable/WORM storage or an independent
   security account.
4. Compare the current chain head with the last externally anchored checkpoint
   during verification and recovery.
5. Restrict UPDATE/DELETE privileges on audit, chain, and head tables. Use a
   separately controlled maintenance identity for retention and archival.
6. Alert on verification failures and audit append failures.

Do not treat a locally stored hash chain as cryptographic immutability. A
privileged actor who can rewrite all local chain state can recompute valid
hashes. External anchoring is the trust boundary that makes wholesale
rewriting detectable.

## API boundaries

The hash-chain capability is optional at the runtime contract level. Hosts
that use adapters without `PluginRevocationAccessAuditChainStore` continue to
support ordinary append and inspection but do not have chain verification.
Hosts should authorize verification requests using the same dedicated
audit-trail authorization boundary as audit inspection.


## Signed external checkpoints

The runtime now defines `PluginRevocationAccessAuditCheckpointService` and
host-owned ports for signing, signature verification, authorization, and
independent checkpoint storage. SQLite and PostgreSQL audit adapters expose
the additional `PluginRevocationAccessAuditCheckpointChainVerifier` capability
to prove that a previously anchored sequence/hash pair still exists in the
verified local chain.

A checkpoint signs a versioned canonical payload containing scope, sequence,
head hash, UTC creation time, signing key ID, and the digest of the preceding
checkpoint. The external store's append operation receives the expected
previous digest and must enforce that compare-and-append atomically. This
prevents concurrent checkpoint writers from silently forking history.

Before creating a new checkpoint, the service verifies the complete local
chain, verifies the previous checkpoint signature, rejects a local rollback,
and confirms that the previous anchor remains in the chain. Verification of
the latest checkpoint repeats signature validation and checks that its exact
head is still present in the valid local chain. A merely larger local sequence
is not sufficient.

### Host responsibilities

- Implement signer and verifier using a managed key service or HSM; never put
  private signing keys in Alhambra runtime configuration.
- Implement checkpoint storage in a separately administered account or
  immutable/WORM service. Do not store the only checkpoint copy beside the
  audit chain it protects.
- Enforce atomic compare-and-append using `expectedPreviousDigest`.
- Preserve historical verification keys or a trusted key-rotation policy so
  old signatures remain verifiable.
- Authorize checkpoint creation and verification independently of ordinary
  operational inspection.
- Schedule checkpoint creation and verification, alert on failures, and retain
  exported checkpoint evidence outside the application database.

The runtime deliberately does not select a signature algorithm, KMS, cloud
provider, scheduler, or external storage vendor. It also does not recursively
append checkpoint events to the audit chain being checkpointed.
