# alhambra_lifecycle_sqlite_store

SQLite-backed implementation of Alhambra's storage-neutral
`CompositionLifecycleEventStore` contract.

## Usage

```dart
final store = SqliteCompositionLifecycleEventStore.open(
  path: '${supportDirectory.path}/alhambra/lifecycle.sqlite',
);

await store.append(event);
final recent = await store.query(
  CompositionLifecycleEventQuery(ownerId: 'editor-plugin', limit: 50),
);

// Close stores opened with .open() during orderly shutdown.
await store.close();
```

A host may instead supply a `sqlite3` `Database` instance. In that case the
host retains ownership and `store.close()` does not dispose the database.

## Guarantees

- Event inserts and owner associations commit in one `BEGIN IMMEDIATE`
  transaction.
- `eventId` is a primary key. Identical encoded retries are no-ops;
  conflicting payloads throw the API-level
  `CompositionLifecycleEventIdentityConflictException`.
- Queries use SQL predicates and indexes for time, correlation, operation,
  status, and owner filtering.
- Composite keyset cursors use `(timestamp_micros, event_id_sort_key)`.
  The sort key encodes Dart UTF-16 code units as fixed-width hexadecimal so
  SQLite ordering matches Dart's `String.compareTo`, including supplementary
  Unicode characters.
- The event codec payload is retained as the canonical source of event fields;
  indexed columns are query projections, not a replacement event schema.
- Schema version is tracked with `PRAGMA user_version`. Ordered migrations run
  one at a time inside transactions; a failed migration rolls back without
  advancing the version. Databases created by a newer schema are rejected.
- Version 2 adds a composite status/operation/time index for combined filtered
  history queries; version 1 databases upgrade automatically.
- File-backed databases use WAL mode and a 5-second busy timeout.

## Operational considerations

The `sqlite3` Dart API is synchronous. The direct adapter preserves a
simple host-owned connection model and does not move work off the calling
isolate. Flutter/UI hosts should use `SqliteLifecycleEventStoreWorker.open`:
it starts a long-lived isolate, opens the database there, and transfers only
JSON event payloads and primitive query values across the message boundary.
SQLite connections and statements never cross isolates. The worker serializes
commands and exposes explicit `close()` and `checkpoint()` operations.

Both adapters expose explicit WAL checkpointing. PASSIVE is recommended for
routine maintenance; FULL, RESTART, and TRUNCATE are available for controlled
maintenance. Results include SQLite's busy, log-frame, and checkpointed-frame
counters so callers can detect incomplete checkpoints. A long-lived reader
transaction can pin an older WAL snapshot and prevent a checkpoint from
advancing through newer frames. Keep read transactions short; monitor the
checkpoint counters and WAL file size, and retry a checkpoint after readers
release their snapshots. The test suite exercises this behavior against a
second connection for both direct and worker-backed stores.

The adapter does not own databases passed to its constructor. Only instances
created with `SqliteCompositionLifecycleEventStore.open()` close their
database when `close()` is called.

Run the shared behavioral contract and adapter-specific tests with
`dart test` from this package.

## Retention and compaction

The direct SQLite adapter and isolate worker expose `compact`, matching the
JSONL adapter's retention policy:

- `retainFrom` is an inclusive UTC boundary; older events are deleted.
- `maxEvents` keeps the newest N events ordered by timestamp and event ID.
- When both are supplied, the time filter is applied first, then the count cap.
- At least one policy is required and `maxEvents` must be greater than zero.
- Event deletion and owner-association cleanup run in one transaction; the
  method returns the number of deleted events.

SQLite compaction deletes rows but does not automatically run `VACUUM` or
truncate the WAL. This avoids surprising long-running maintenance work during
retention. Use the explicit WAL checkpoint API for checkpointing; schedule
`VACUUM` separately during a controlled maintenance window if reclaiming the
main database file's disk space is required.

## Performance checks

Run the local benchmark from this package at increasing data volumes:

```sh
dart run benchmark/sqlite_lifecycle_store_benchmark.dart 10000
dart run benchmark/sqlite_lifecycle_store_benchmark.dart 100000
dart run benchmark/sqlite_lifecycle_store_benchmark.dart 1000000
```

The harness reports append throughput, 30 warmed filtered-query samples
(p50/p95), database and pre-checkpoint WAL file sizes, and checkpoint counters.
The 100K and 1M profiles are intended for local scale characterization and
should not be treated as CI thresholds. Compare runs only when Dart/SQLite
versions, machine, filesystem, and event count are recorded. The adapter tests
also inspect `EXPLAIN QUERY PLAN` for the combined status/operation query path.
