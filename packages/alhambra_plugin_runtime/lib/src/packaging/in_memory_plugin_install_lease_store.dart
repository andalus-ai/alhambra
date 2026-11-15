import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

/// Single-process reference implementation of operation leases.
///
/// This store is suitable for deterministic tests and single-isolate hosts
/// only. It is not durable and cannot coordinate separate processes or hosts.
final class InMemoryPluginInstallOperationLeaseStore
    implements PluginInstallOperationLeaseStore {
  final Map<String, PluginInstallOperationLease> _active = {};
  final Map<String, int> _lastToken = {};

  static DateTime _utc(DateTime value) => value.toUtc();

  static void _validateIdentity(String operationId, String ownerId) {
    if (operationId.trim().isEmpty || ownerId.trim().isEmpty) {
      throw ArgumentError('Operation and owner IDs must not be empty.');
    }
  }

  static void _validateDuration(Duration duration) {
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'leaseDuration', 'Must be positive.');
    }
  }

  bool _matches(PluginInstallOperationLease current,
      PluginInstallOperationLease candidate) =>
      current.operationId == candidate.operationId &&
      current.ownerId == candidate.ownerId &&
      current.fencingToken == candidate.fencingToken;

  @override
  Future<PluginInstallOperationLease?> acquire({
    required String operationId,
    required String ownerId,
    required DateTime now,
    required Duration leaseDuration,
  }) async {
    _validateIdentity(operationId, ownerId);
    _validateDuration(leaseDuration);
    final instant = _utc(now);
    final current = _active[operationId];
    if (current != null && current.isValidAt(instant)) {
      return current.ownerId == ownerId ? current : null;
    }
    final token = (_lastToken[operationId] ?? 0) + 1;
    _lastToken[operationId] = token;
    final lease = PluginInstallOperationLease(
      operationId: operationId,
      ownerId: ownerId,
      fencingToken: token,
      acquiredAt: instant,
      expiresAt: instant.add(leaseDuration),
    );
    _active[operationId] = lease;
    return lease;
  }

  @override
  Future<PluginInstallOperationLease?> renew({
    required PluginInstallOperationLease lease,
    required DateTime now,
    required Duration leaseDuration,
  }) async {
    _validateDuration(leaseDuration);
    final instant = _utc(now);
    final current = _active[lease.operationId];
    if (current == null ||
        !_matches(current, lease) ||
        !current.isValidAt(instant)) {
      return null;
    }
    final renewed = PluginInstallOperationLease(
      operationId: current.operationId,
      ownerId: current.ownerId,
      fencingToken: current.fencingToken,
      acquiredAt: current.acquiredAt,
      expiresAt: instant.add(leaseDuration),
    );
    _active[lease.operationId] = renewed;
    return renewed;
  }

  @override
  Future<bool> release({
    required PluginInstallOperationLease lease,
    required DateTime now,
  }) async {
    final current = _active[lease.operationId];
    if (current == null || !_matches(current, lease)) return false;
    _active.remove(lease.operationId);
    return true;
  }

  @override
  Future<bool> isCurrent({
    required PluginInstallOperationLease lease,
    required DateTime now,
  }) async {
    final current = _active[lease.operationId];
    return current != null &&
        _matches(current, lease) &&
        current.isValidAt(_utc(now));
  }
}
