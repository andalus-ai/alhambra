import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

import 'jsonl_composition_lifecycle_event_store.dart';

/// Durable + live diagnostics facade for a JSONL-backed composition runtime.
///
/// Queries flush accepted journal writes first, then merge durable results with
/// the runtime's bounded live window. This makes events rejected by the
/// persistence queue visible while avoiding duplicates for events already
/// written to disk.
final class JsonlCompositionLifecycleDiagnostics {
  final JsonlCompositionLifecycleEventStore store;
  final CompositionLifecycleEventJournal journal;
  final CompositionRuntime runtime;

  const JsonlCompositionLifecycleDiagnostics({
    required this.store,
    required this.journal,
    required this.runtime,
  });

  /// Queries durable history and overlays events still present in live memory.
  ///
  /// Durable storage remains the source of historical coverage. Live events
  /// outside the journal's accepted durability boundary are included when
  /// present in the runtime's bounded history.
  Future<List<CompositionLifecycleEvent>> query(
    CompositionLifecycleEventQuery query,
  ) async {
    await journal.flush();
    final durable = await store.query(query);
    final live = runtime.queryLifecycleEvents(
      correlationId: query.correlationId,
      ownerId: query.ownerId,
      operation: query.operation,
      status: query.status,
      from: query.from,
      to: query.to,
      before: query.before,
      limit: runtime.lifecycleEvents.isEmpty ? 1 : runtime.lifecycleEvents.length,
    );
    final merged = _merge(durable, live);
    return List.unmodifiable(merged.take(query.limit));
  }

  /// Builds an owner summary over durable history plus the live runtime window.
  ///
  /// Event counts are exact for the JSONL file and the current in-memory
  /// history. Duplicate records present in both sources are counted once.
  Future<CompositionLifecycleOwnerSummary?> ownerSummary(
    String ownerId,
  ) async {
    await journal.flush();
    final durable = await store.query(
      CompositionLifecycleEventQuery(
        ownerId: ownerId,
        limit: 0x7fffffff,
      ),
    );
    final live = runtime.queryLifecycleEvents(
      ownerId: ownerId,
      limit: runtime.lifecycleEvents.isEmpty ? 1 : runtime.lifecycleEvents.length,
    );
    final events = _merge(durable, live);
    final runtimeSummary = runtime.ownerLifecycleSummary(ownerId);
    if (events.isEmpty && runtimeSummary == null) return null;

    final failures = events
        .where((event) => event.status == CompositionLifecycleStatus.failed)
        .toList(growable: false);
    return CompositionLifecycleOwnerSummary(
      ownerId: ownerId,
      state: runtimeSummary?.state,
      eventCount: events.length,
      failureCount: failures.length,
      lastEventAt: events.isEmpty ? null : events.last.timestamp,
      lastFailure: failures.isEmpty ? null : failures.last,
    );
  }

  /// Returns summaries for every owner found in durable or live history.
  Future<List<CompositionLifecycleOwnerSummary>> ownerSummaries() async {
    await journal.flush();
    final durable = await store.query(
      CompositionLifecycleEventQuery(limit: 0x7fffffff),
    );
    final live = runtime.lifecycleEvents;
    final events = _merge(durable, live);
    final ownerIds = <String>{
      ...runtime.ownerStates.keys,
      for (final event in events) ...event.ownerIds,
    }.toList()
      ..sort();

    final summaries = <CompositionLifecycleOwnerSummary>[];
    for (final ownerId in ownerIds) {
      final ownerEvents = events
          .where((event) => event.ownerIds.contains(ownerId))
          .toList(growable: false);
      final failures = ownerEvents
          .where((event) => event.status == CompositionLifecycleStatus.failed)
          .toList(growable: false);
      summaries.add(CompositionLifecycleOwnerSummary(
        ownerId: ownerId,
        state: runtime.ownerState(ownerId),
        eventCount: ownerEvents.length,
        failureCount: failures.length,
        lastEventAt:
            ownerEvents.isEmpty ? null : ownerEvents.last.timestamp,
        lastFailure: failures.isEmpty ? null : failures.last,
      ));
    }
    return List.unmodifiable(summaries);
  }

  List<CompositionLifecycleEvent> _merge(
    List<CompositionLifecycleEvent> durable,
    List<CompositionLifecycleEvent> live,
  ) {
    final byIdentity = <String, CompositionLifecycleEvent>{};
    for (final event in [...durable, ...live]) {
      byIdentity.putIfAbsent(_identity(event), () => event);
    }
    final result = byIdentity.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }

  /// The event schema intentionally has no storage-specific identifier.
  /// This deterministic value identifies equivalent decoded/in-memory records.
  String _identity(CompositionLifecycleEvent event) => [
        event.correlationId,
        event.operation.name,
        event.status.name,
        event.timestamp.toUtc().microsecondsSinceEpoch,
        event.nodeIds.join('\u001f'),
        event.ownerIds.join('\u001f'),
        event.duration?.inMicroseconds ?? '',
        event.errorType ?? '',
        event.errorMessage ?? '',
      ].join('\u001e');
}
