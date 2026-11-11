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
```

The adapter is intentionally separate from `alhambra_plugin_api` and
`alhambra_plugin_runtime`: it uses `dart:io` and is suitable for native
Dart/Flutter hosts, not web builds.

## Guarantees and limits

- Appends are serialized within one store instance and flushed before return.
- Query replays versioned records and supports the API query filters.
- An unterminated final line is treated as an interrupted append and ignored.
- A malformed newline-terminated record is reported as corruption.
- This initial implementation assumes one process writes the file.
- It does not yet compact or truncate the file; retention/compaction is a
  separate operational policy and should be added with explicit backup and
  atomic-replacement semantics.
