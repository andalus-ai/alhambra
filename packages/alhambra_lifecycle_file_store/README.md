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

## Recovery and operations

- Keep the JSONL file and its sparse-index sidecar in an application-private,
  writable directory with enough free space for normal appends and a temporary
  full-file replacement during compaction.
- If the process stops during an append, an unterminated final line is ignored
  by reads and removed before the next append. A newline-terminated malformed
  record is not auto-discarded: treat it as corruption and preserve a copy of
  the original file before attempting manual recovery.
- If an append or compaction reports an I/O error, stop scheduling maintenance,
  retain the original log and any `.compact-*` backup artifacts, and surface
  the error to the host. Do not delete the authoritative JSONL file to repair
  the rebuildable sparse index.
- After restoring filesystem access and free space, reopen the adapter and
  query a small page. The sidecar can be rebuilt from the authoritative log;
  verify event counts and representative event IDs before resuming writes.
- Compaction temporarily needs space for a replacement log. Schedule it when
  sufficient free space is available and keep an external backup for data
  that must survive device or filesystem failure.
- This adapter is single-process-writer only. For multiple processes, use an
  external coordination mechanism or the SQLite adapter.

These procedures do not provide power-loss durability or filesystem-level
atomicity guarantees beyond the host filesystem's documented behavior.

## Guarantees and limits

- Appends are serialized within one store instance and flushed before return.
- Appending an event whose `eventId` and payload already exist is an idempotent no-op; reusing an ID with a different payload throws `CompositionLifecycleEventIdentityConflictException` (also exposed through the backwards-compatible file-store alias).
- The JSONL log is authoritative. Query pages collapse repeated IDs within the selected page. When an append retries an existing ID, the adapter checks all Bloom-positive blocks and rejects conflicting payloads as corruption.
- A companion `.sparse-index.json` sidecar stores one checkpoint per 128 complete JSONL records. Each checkpoint includes byte offsets, a composite timestamp/event-ID range, and a compact Bloom filter for event-ID lookup.
- The sidecar is a rebuildable cache; JSONL remains authoritative. On reopen, the adapter validates the final indexed record and scans only the unindexed tail. Under normal operation this is at most 127 complete records; repeated checkpoint-write failures can leave a larger tail. Missing, malformed, or stale checkpoints trigger a rebuild.
- Time-window and cursor queries skip blocks whose recorded ranges cannot match. Matching records are streamed block-by-block, and only the requested page is retained in memory. Queries filtered only by owner/correlation/operation/status may still need to inspect every block because this sparse index intentionally does not maintain unbounded per-value posting lists.
- Event-ID Bloom filters have no false negatives; false positives only cause an extra block read. Reusing an ID with an identical payload is a no-op; conflicting payloads are rejected. The sparse checkpoint uses a checksum and validates its final indexed record before reuse.
- Compaction invalidates the sidecar. The next operation rebuilds checkpoints from the compacted log. The sidecar format is private to this adapter and does not change the portable JSONL event format.
- Query results are oldest-first, ordered by `(timestamp, eventId)`.
- `CompositionLifecycleEventQuery.after` and `beforeCursor` provide exclusive keyset pagination; backward pages return the nearest preceding records in oldest-first order.
- The legacy timestamp-only `before` filter remains supported for compatibility.
- The JSONL codec writes schema version 2 and reads both version 1 and version 2. Version 1 records receive a deterministic legacy identity when decoded.
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


## Health and diagnostics

`JsonlCompositionLifecycleEventStore` implements the optional `CompositionLifecycleStorageHealthProvider` capability. Call `inspectHealth()` to obtain the current JSONL byte size, sparse-index sidecar size, last successful append observed by this store instance, and the most recent append error. The `JsonlCompositionLifecycleRuntime` facade additionally reports pending and rejected journal writes. A degraded snapshot signals a known write error or rejected journal events; an unavailable snapshot means the health inspection itself could not read the backing files. Health inspection does not scan the full log, validate every record, predict free disk space, or guarantee the next append.
