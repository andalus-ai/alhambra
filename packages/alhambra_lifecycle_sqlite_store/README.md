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
- Schema version is tracked with `PRAGMA user_version`. The adapter rejects
  databases created by a newer schema version.
- File-backed databases use WAL mode and a 5-second busy timeout.

## Operational considerations

The `sqlite3` Dart API is synchronous. This adapter wraps operations in the
asynchronous store interface, but it does not move database work off the
calling isolate. Applications with latency-sensitive UI threads should own
the database on a dedicated isolate and expose a message-based adapter.

The adapter does not own databases passed to its constructor. Only instances
created with `SqliteCompositionLifecycleEventStore.open()` close their
database when `close()` is called.

Run the shared behavioral contract and adapter-specific tests with
`dart test` from this package.
