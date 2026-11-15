import 'dart:async';

import 'dart:io';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

import 'jsonl_composition_lifecycle_event_store.dart';

/// Ready-to-use composition runtime backed by a durable JSONL event journal.
///
/// The synchronous runtime event sink only enqueues diagnostics. Storage I/O
/// happens asynchronously through [journal], so composition callbacks do not
/// wait for disk writes. Hosts must call [close] during orderly shutdown.
final class JsonlCompositionLifecycleRuntime {
  late final JsonlCompositionLifecycleEventStore store;
  late final CompositionLifecycleEventJournal journal;
  late final DefaultCompositionRuntime runtime;

  JsonlCompositionLifecycleRuntime({
    required File file,
    int maxPendingEvents = 512,
    int maxLifecycleEvents = 1000,
    CompositionLifecycleEventJsonCodec? codec,
    void Function(Object error, StackTrace stackTrace)? onWriteError,
    void Function(String ownerId)? onOwnerDeactivated,
  }) {
    store = JsonlCompositionLifecycleEventStore(file: file, codec: codec);
    journal = CompositionLifecycleEventJournal(
      store: store,
      maxPendingEvents: maxPendingEvents,
      onWriteError: onWriteError,
    );
    runtime = DefaultCompositionRuntime(
      onLifecycleEvent: journal.call,
      maxLifecycleEvents: maxLifecycleEvents,
      onOwnerDeactivated: onOwnerDeactivated,
    );
  }

  /// Number of events accepted by the journal but not yet durably appended.
  int get pendingEventCount => journal.pendingCount;

  /// Number of events rejected because the queue was full or shutting down.
  int get rejectedEventCount => journal.rejectedEventCount;

  /// Last asynchronous persistence failure, if any.
  Object? get lastWriteError => journal.lastError;

  /// Combines backend footprint with the runtime journal's live queue state.
  Future<CompositionLifecycleStorageHealth> inspectHealth() async {
    final storage = await store.inspectHealth();
    final pending = pendingEventCount;
    final rejected = rejectedEventCount;
    final degraded = storage.state != CompositionLifecycleStorageHealthState.healthy ||
        lastWriteError != null ||
        rejected > 0;
    return CompositionLifecycleStorageHealth(
      state: degraded
          ? (storage.state == CompositionLifecycleStorageHealthState.unavailable
              ? CompositionLifecycleStorageHealthState.unavailable
              : CompositionLifecycleStorageHealthState.degraded)
          : CompositionLifecycleStorageHealthState.healthy,
      checkedAt: storage.checkedAt,
      lastSuccessfulWriteAt: storage.lastSuccessfulWriteAt,
      lastError: lastWriteError?.toString() ?? storage.lastError,
      pendingWrites: pending,
      rejectedWrites: rejected,
      recordCount: storage.recordCount,
      primaryStorageBytes: storage.primaryStorageBytes,
      auxiliaryStorageBytes: storage.auxiliaryStorageBytes,
      metrics: storage.metrics,
    );
  }

  /// Waits until all currently accepted lifecycle events are persisted.
  Future<void> flush() => journal.flush();

  /// Retries the failed event and then drains the remaining accepted events.
  Future<void> retryFailedWrites() => journal.retryFailedWrites();

  /// Flushes accepted diagnostics before applying the requested retention.
  ///
  /// This prevents compaction from running ahead of events already accepted
  /// by the runtime but still waiting in the asynchronous journal.
  Future<int> compact({
    DateTime? retainFrom,
    int? maxEvents,
  }) async {
    await journal.flush();
    return store.compact(retainFrom: retainFrom, maxEvents: maxEvents);
  }

  /// Queries durable events after flushing events accepted before this call.
  Future<List<CompositionLifecycleEvent>> query(
    CompositionLifecycleEventQuery query,
  ) async {
    await journal.flush();
    return store.query(query);
  }

  /// Stops event intake and waits for all accepted diagnostics to persist.
  ///
  /// If persistence fails, the journal remains in its recoverable closing
  /// state. Call [retryFailedWrites] and then [close] again.
  Future<void> close() => journal.close();
}
