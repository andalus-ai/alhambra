# alhambra_lifecycle_file_store

A platform-specific, single-process JSON Lines persistence adapter for
Alhambra composition lifecycle diagnostics.

## Runtime integration

Use `JsonlCompositionLifecycleRuntime` when a native Dart/Flutter host wants
a ready-wired composition runtime and durable lifecycle diagnostics:

```dart
final diagnostics = JsonlCompositionLifecycleRuntime(
  file: File('${supportDirectory.path}/alhambra/lifecycle.jsonl'),
  maxPendingEvents: 512,
  maxLifecycleEvents: 1000,
  onWriteError: (error, stackTrace) {
    // Forward to the host's own logger/health reporting.
  },
);

final runtime = diagnostics.runtime;
final transaction = runtime.beginTransaction(
  lifecycle: pluginLifecycle,
  correlationId: 'plugin-install-42',
);
// Stage contributions and commit as usual.

final recentEvents = await diagnostics.query(
  CompositionLifecycleEventQuery(ownerId: 'editor-plugin', limit: 50),
);

// On orderly application shutdown:
await diagnostics.close();
```

The runtime callback only enqueues events; it does not wait for file I/O.
Monitor `pendingEventCount`, `rejectedEventCount`, and `lastWriteError`.
If a write fails, the failed event remains queued: call
`retryFailedWrites()`, then `flush()` or `close()` again. A failed close
leaves intake stopped so the host can retry without accepting more events.

Use `diagnostics.compact(...)` rather than calling `store.compact(...)`
directly while the runtime is active. The facade flushes accepted journal
events before compaction. Likewise, `diagnostics.query(...)` flushes accepted
events before reading the durable store.

## Direct store usage

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
- Query results are oldest-first, with stable append order for equal timestamps.
- An unterminated final line (including an incomplete UTF-8 sequence) is
  treated as an interrupted append and ignored; the next append repairs it.
- A malformed newline-terminated record is reported as corruption.
- `compact(retainFrom:)` keeps events at or after the inclusive UTC boundary.
- `compact(maxEvents:)` keeps the newest N events; both policies may be used
  together, applying the time window before the count cap.
- Runtime integration uses a bounded asynchronous journal; queue overflow is
  explicit and counted rather than silently growing without limit.
- The facade flushes before querying or compacting and exposes retry/close
  lifecycle operations.
- Compaction is serialized with appends submitted to the same store instance.
- A complete replacement is written and flushed before the old file is moved
  aside; failed installation triggers a best-effort restore.
- The adapter assumes one process writes the file. It does not provide
  cross-process locking.
- Rename guarantees depend on the host filesystem and do not claim
  transactional durability against power loss or device failure.
