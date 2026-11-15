/// Optional, backend-neutral health and footprint reporting for lifecycle stores.
///
/// Null metrics mean that the adapter cannot report the value; they must not
/// be interpreted as zero. A snapshot is observational and does not reserve
/// capacity or guarantee that the next write will succeed.
enum CompositionLifecycleStorageHealthState {
  healthy,
  degraded,
  unavailable,
  unknown,
}

final class CompositionLifecycleStorageHealth {
  final CompositionLifecycleStorageHealthState state;
  final DateTime checkedAt;
  final DateTime? lastSuccessfulWriteAt;
  final String? lastError;
  final int? pendingWrites;
  final int? rejectedWrites;
  final int? recordCount;
  final int? primaryStorageBytes;
  final int? auxiliaryStorageBytes;
  final Map<String, Object?> metrics;

  CompositionLifecycleStorageHealth({
    required this.state,
    required this.checkedAt,
    this.lastSuccessfulWriteAt,
    this.lastError,
    this.pendingWrites,
    this.rejectedWrites,
    this.recordCount,
    this.primaryStorageBytes,
    this.auxiliaryStorageBytes,
    Map<String, Object?> metrics = const {},
  }) : metrics = Map.unmodifiable(metrics) {
    if (pendingWrites != null && pendingWrites! < 0) {
      throw ArgumentError.value(pendingWrites, 'pendingWrites');
    }
    if (rejectedWrites != null && rejectedWrites! < 0) {
      throw ArgumentError.value(rejectedWrites, 'rejectedWrites');
    }
    if (recordCount != null && recordCount! < 0) {
      throw ArgumentError.value(recordCount, 'recordCount');
    }
    if (primaryStorageBytes != null && primaryStorageBytes! < 0) {
      throw ArgumentError.value(primaryStorageBytes, 'primaryStorageBytes');
    }
    if (auxiliaryStorageBytes != null && auxiliaryStorageBytes! < 0) {
      throw ArgumentError.value(auxiliaryStorageBytes, 'auxiliaryStorageBytes');
    }
  }
}

/// Optional capability implemented by stores that can inspect their health.
///
/// Kept separate from [CompositionLifecycleEventStore] so existing and
/// third-party adapters remain source-compatible.
abstract interface class CompositionLifecycleStorageHealthProvider {
  Future<CompositionLifecycleStorageHealth> inspectHealth();
}
