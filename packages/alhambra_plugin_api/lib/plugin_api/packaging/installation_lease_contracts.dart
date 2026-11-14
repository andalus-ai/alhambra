/// A time-bounded ownership claim for one plugin installation operation.
///
/// [fencingToken] is monotonically increasing for each successful acquisition
/// of the operation. Adapters must persist the highest token they have
/// accepted and reject side effects from lower tokens; checking lease expiry
/// alone is not sufficient to fence a paused worker.
final class PluginInstallOperationLease {
  final String operationId;
  final String ownerId;
  final int fencingToken;
  final DateTime acquiredAt;
  final DateTime expiresAt;

  const PluginInstallOperationLease({
    required this.operationId,
    required this.ownerId,
    required this.fencingToken,
    required this.acquiredAt,
    required this.expiresAt,
  });

  bool isValidAt(DateTime instant) => expiresAt.isAfter(instant.toUtc());
}

/// Atomic lease coordination for competing installer and recovery workers.
///
/// Implementations must make acquire/renew/release linearizable for each
/// operation ID. Tokens must never be reused, including after lease expiry or
/// process restart. A production implementation must persist token counters.
abstract interface class PluginInstallOperationLeaseStore {
  /// Returns null when another owner holds an unexpired lease.
  ///
  /// Reacquisition by the same owner is idempotent and returns its current
  /// lease; it must not mint a new fencing token.
  Future<PluginInstallOperationLease?> acquire({
    required String operationId,
    required String ownerId,
    required DateTime now,
    required Duration leaseDuration,
  });

  /// Renews only the exact current owner/token pair before it expires.
  /// Returns null when ownership was lost or the lease has expired.
  Future<PluginInstallOperationLease?> renew({
    required PluginInstallOperationLease lease,
    required DateTime now,
    required Duration leaseDuration,
  });

  /// Releases only the exact current owner/token pair.
  Future<bool> release({
    required PluginInstallOperationLease lease,
    required DateTime now,
  });

  /// Checks exact owner/token identity and expiry.
  Future<bool> isCurrent({
    required PluginInstallOperationLease lease,
    required DateTime now,
  });
}
