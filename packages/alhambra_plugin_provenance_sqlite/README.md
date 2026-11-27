# alhambra_plugin_provenance_sqlite

Optional SQLite persistence adapters for Alhambra recovery provenance. The
neutral `alhambra_plugin_runtime` package remains database-independent.

## Contracts

`SqlitePluginRecoveryProvenancePersistence` owns one SQLite connection and
exposes three contract adapters:

- `provenanceStore` — append-only recovery provenance event chain;
- `anchorStore` — signed checkpoint anchors, partitioned by chain ID;
- `keyHistoryStore` — append-only signing-key activation, rotation, retirement,
  and revocation history.

A database instance represents one provenance event chain because the runtime
provenance-store contract is chain-local and does not include a chain ID in its
append method. Anchor history can contain multiple chain IDs. Key history is
shared by the database.

## Bootstrap

```dart
final persistence =
    SqlitePluginRecoveryProvenancePersistence('/var/lib/app/recovery-audit.sqlite');

final appender = PluginRecoveryProvenanceAppender(
  store: persistence.provenanceStore,
  digestProvider: digestProvider,
  digestAlgorithm: 'SHA-256',
  signer: signer,
  signerKeyId: 'recovery-audit-2026',
  signatureAlgorithm: 'Ed25519',
);

final keyHistory = PluginRecoverySigningKeyHistoryInspector(
  store: persistence.keyHistoryStore,
);

// The host owns the database lifecycle.
await hostShutdown.register(() => persistence.close());
```

Call `close()` when the owning host shuts down. A private in-memory
constructor is available for tests only.

## Transaction and durability model

Every append uses `BEGIN IMMEDIATE`, reads the current sequence/head while
holding SQLite's writer reservation, validates the caller's expected sequence
(and expected event digest for provenance), inserts the row, then commits.
Stale writers return `false`; duplicate IDs and other constraint violations
fail without a partial write. SQLite serializes writers across independent
connections to the same database file.

The adapter configures a five-second busy timeout, foreign keys, WAL for
file-backed databases, and `synchronous=FULL`. Busy/locked failures remain
visible to the caller and should be handled by host retry policy. This is
embedded, single-host persistence—not a multi-host database or distributed
consensus mechanism. Use a server database adapter for multi-host deployments.
Do not place a live SQLite database on object storage or an unreliable network
filesystem.

## Schema and migrations

Schema version 1 creates the provenance-event, anchor, and signing-key-history
tables plus the key-history lookup index. Migration runs inside an immediate
transaction and advances `PRAGMA user_version` only after all objects exist.
Opening a database with a newer schema version fails closed. The adapter does
not rewrite or prune append-only history.

## Operational diagnostics and WAL maintenance

`inspect()` returns schema/configuration values, append-only table counts,
and the result of SQLite `PRAGMA quick_check`. It is read-only but may scan
the database; call it on an operational schedule rather than on every write.
The fields are gathered by separate statements and can reflect concurrent
writes, so counts are advisory rather than a consistent transactional
snapshot.

Use `checkpointWal()` for explicit WAL maintenance. It defaults to
`passive`; `full`, `restart`, and `truncate` are available for host-managed
maintenance windows. In particular, `truncate` may wait for readers. No
checkpoint runs automatically, and a WAL checkpoint is not a backup.

The adapter exposes `backupTo(destinationPath)`, implemented with SQLite's
`VACUUM INTO` so SQLite creates a consistent standalone snapshot while
respecting its own locking and WAL state. The destination must not already
exist. The adapter does not encrypt, upload, rotate, or retain backup files;
hosts must protect the destination and manage backup lifecycle. After restore,
run the provenance and anchor verifiers against independently retained signed
anchors.

The adapter does not expose retention deletion or automatic repair. Hosts
must own immutable retention, integrity incident response, and verification
against independently retained anchors.

## Integrity and security boundaries

- The adapter stores event digests and signatures exactly as supplied; it does
  not calculate digests, sign, verify, or manage keys.
- Run `PluginRecoveryProvenanceVerifier` and
  `PluginRecoveryProvenanceAnchorVerifier` for integrity checks.
- Authorization, tenant isolation, backup encryption, key custody, retention,
  external anchoring, and restore procedures remain host responsibilities.
- SQLite constraints and transaction locks protect local append sequencing;
  they do not prevent a privileged operator from modifying or replacing the
  database file. Use independently protected backups/anchors for tamper
  evidence.
- The package exposes no update/delete methods for append-only records.
