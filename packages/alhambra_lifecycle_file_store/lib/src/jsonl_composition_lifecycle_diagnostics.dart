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
    final durable = await store.query(CompositionLifecycleEventQuery(
      correlationId: query.correlationId,
      ownerId: query.ownerId,
      operation: query.operation,
      status: query.status,
      from: query.from,
      to: query.to,
      before: query.before,
      after: query.after,
      beforeCursor: query.beforeCursor,
      limit: 0x7fffffff,
    ));
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
    final merged = _merge(durable, live).where((event) {
      if (query.after != null && _compareEventToCursor(event, query.after!) <= 0) return false;
      if (query.beforeCursor != null && _compareEventToCursor(event, query.beforeCursor!) >= 0) return false;
      return true;
    }).toList(growable: false);
    if (query.beforeCursor != null && merged.length > query.limit) {
      return List.unmodifiable(merged.skip(merged.length - query.limit));
    }
    return List.unmodifiable(merged.take(query.limit));
  }

  /// Reads a complete correlation timeline across durable and live history.
  Future<List<CompositionLifecycleEvent>> timelineForCorrelation(
    String correlationId, {
    DateTime? from,
    DateTime? to,
    DateTime? before,
    int limit = 100,
  }) =>
      query(CompositionLifecycleEventQuery(
        correlationId: correlationId,
        from: from,
        to: to,
        before: before,
        limit: limit,
      ));

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
    final indexed = byIdentity.values.indexed.toList()
      ..sort((a, b) {
        final byTime = a.$2.timestamp.compareTo(b.$2.timestamp);
        if (byTime != 0) return byTime;
        final byId = a.$2.eventId.compareTo(b.$2.eventId);
        return byId != 0 ? byId : a.$1.compareTo(b.$1);
      });
    return indexed.map((entry) => entry.$2).toList(growable: false);
  }

  int _compareEventToCursor(CompositionLifecycleEvent event, CompositionLifecycleEventCursor cursor) {
    final byTime = event.timestamp.compareTo(cursor.timestamp);
    return byTime != 0 ? byTime : event.eventId.compareTo(cursor.eventId);
  }

  String _identity(CompositionLifecycleEvent event) => event.eventId;

}
