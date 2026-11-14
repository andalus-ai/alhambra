/// Explicit maintenance request for a lifecycle event store.
///
/// Maintenance is never scheduled implicitly by an adapter. Callers own
/// scheduling, retention policy, and maintenance windows.
final class CompositionLifecycleStorageMaintenanceRequest {
  final DateTime? retainFrom;
  final int? maxEvents;
  final bool checkpoint;

  const CompositionLifecycleStorageMaintenanceRequest({
    this.retainFrom,
    this.maxEvents,
    this.checkpoint = false,
  }) {
    if (retainFrom == null && maxEvents == null && !checkpoint) {
      throw ArgumentError('At least one maintenance action must be requested.');
    }
    if (maxEvents != null && maxEvents < 1) {
      throw ArgumentError.value(maxEvents, 'maxEvents', 'Must be greater than zero.');
    }
  }
}

/// Outcome of an explicit lifecycle storage maintenance operation.
///
/// Null values indicate that the adapter does not support or report that
/// measurement. A partial result means at least one requested action could
/// not be performed; inspect [warnings] and [metrics].
final class CompositionLifecycleStorageMaintenanceResult {
  final DateTime startedAt;
  final DateTime completedAt;
  final int? recordsRemoved;
  final bool checkpointRequested;
  final bool? checkpointCompleted;
  final List<String> warnings;
  final Map<String, Object?> metrics;

  CompositionLifecycleStorageMaintenanceResult({
    required this.startedAt,
    required this.completedAt,
    this.recordsRemoved,
    required this.checkpointRequested,
    this.checkpointCompleted,
    List<String> warnings = const [],
    Map<String, Object?> metrics = const {},
  })  : warnings = List.unmodifiable(warnings),
        metrics = Map.unmodifiable(metrics) {
    if (recordsRemoved != null && recordsRemoved! < 0) {
      throw ArgumentError.value(recordsRemoved, 'recordsRemoved');
    }
    if (completedAt.isBefore(startedAt)) {
      throw ArgumentError('completedAt must not be before startedAt.');
    }
  }

  bool get partial => warnings.isNotEmpty;
}

/// Optional capability for explicit lifecycle storage maintenance.
///
/// Kept separate from [CompositionLifecycleEventStore] so adapters that do
/// not support compaction or checkpointing remain source-compatible.
abstract interface class CompositionLifecycleStorageMaintenanceProvider {
  Future<CompositionLifecycleStorageMaintenanceResult> maintain(
    CompositionLifecycleStorageMaintenanceRequest request,
  );
}
