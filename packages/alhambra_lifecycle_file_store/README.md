# alhambra_lifecycle_file_store

A platform-specific, single-process JSON Lines persistence adapter for
Alhambra composition lifecycle diagnostics.

## Usage

```dart
final store = JsonlCompositionLifecycleEventStore(
  file: File('${supportDirectory.path}/alhambra/lifecycle.jsonl'),
);
await store.append(event);
final events = await store.query(
  CompositionLifecycleEventQuery(ownerId: 'editor-plugin', limit: 50),
);

// Keep only the newest 10,000 events from the last 30 days.
await store.compact(
  retainFrom: DateTime.now().toUtc().subtract(const Duration(days: 30)),
  maxEvents: 10000,
);
```

The adapter is intentionally separate from `alhambra_plugin_api` and
`alhambra_plugin_runtime`: it uses `dart:io` and is suitable for native
Dart/Flutter hosts, not web builds.

## Guarantees and limits

- Appends are serialized within one store instance and flushed before return.
- Query replays versioned records and supports the API query filters.
- Query results are oldest-first, with stable append order for equal timestamps.
- An unterminated final line (including an incomplete UTF-8 sequence) is
  treated as an interrupted append and ignored.
- A malformed newline-terminated record is reported as corruption.
- `compact(retainFrom:)` keeps events at or after the inclusive UTC boundary.
- `compact(maxEvents:)` keeps the newest N events; both policies may be used
  together, applying the time window before the count cap.
- Compaction is serialized with appends submitted to the same store instance.
- A complete replacement is written and flushed before the old file is moved
  to a temporary backup and the replacement is installed. If installation
  fails, the adapter attempts to restore the original.
- The adapter assumes one process writes the file. It does not provide
  cross-process locking.
- Compaction uses same-filesystem rename operations, but filesystem and
  platform semantics still apply; this is not a transactional guarantee
  against power loss or storage-device failure.
