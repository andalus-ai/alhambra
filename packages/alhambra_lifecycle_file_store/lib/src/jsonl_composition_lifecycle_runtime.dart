import 'dart:async';

import 'dart:io';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

import 'jsonl_composition_lifecycle_event_store.dart';
import 'jsonl_composition_lifecycle_diagnostics.dart';

/// Ready-to-use composition runtime backed by a durable JSONL event journal.
///
/// The synchronous runtime event sink only enqueues lifecycle events. Storage I/O
/// happens asynchronously through [journal], so composition callbacks do not
/// wait for disk writes. Hosts must call [close] during orderly shutdown.
final class JsonlCompositionLifecycleRuntime {
  late final JsonlCompositionLifecycleEventStore store;
  late final CompositionLifecycleEventJournal journal;
  late final DefaultCompositionRuntime runtime;
  late final JsonlCompositionLifecycleDiagnostics lifecycleDiagnostics;

  JsonlCompositionLifecycleRuntime({
    required File file,
    int maxPendingEvents = 512,
    int maxLifecycleEvents = 1000,
    int maxLifecycleEventSubscribers = 64,
    int maxPendingLifecycleEventsPerSubscriber = 128,
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
      maxLifecycleEventSubscribers: maxLifecycleEventSubscribers,
      maxPendingLifecycleEventsPerSubscriber:
          maxPendingLifecycleEventsPerSubscriber,
      onOwnerDeactivated: onOwnerDeactivated,
    );
    lifecycleDiagnostics = JsonlCompositionLifecycleDiagnostics(
      store: store,
      journal: journal,
      runtime: runtime,
    );
  }

  /// Number of events accepted by the journal but not yet durably appended.
  int get pendingEventCount => journal.pendingCount;

  /// Number of events rejected because the queue was full or shutting down.
  int get rejectedEventCount => journal.rejectedEventCount;

  /// Last asynchronous persistence failure, if any.
  Object? get lastWriteError => journal.lastError;

  /// Waits until all currently accepted lifecycle events are persisted.
  Future<void> flush() => journal.flush();

  /// Retries the failed event and then drains the remaining accepted events.
  Future<void> retryFailedWrites() => journal.retryFailedWrites();

  /// Flushes accepted lifecycle events before applying the requested retention.
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

  /// Stops event intake and waits for all accepted lifecycle events to persist.
  ///
  /// If persistence fails, the journal remains in its recoverable closing
  /// state. Call [retryFailedWrites] and then [close] again.
  Future<void> close() => journal.close();
}
