/// Durable, persistence-neutral records for plugin lifecycle recovery.
///
/// A checkpoint records host-observed progress; it does not serialize plugin
/// instances, runtime contexts, credentials, or arbitrary plugin state.
enum PluginLifecycleOperation { startup, shutdown }

/// The last durable phase observed for a plugin lifecycle operation.
///
/// starting and stopping are ambiguous after a process crash and require
/// host recovery logic rather than an automatic retry.
enum PluginLifecycleCheckpointState {
  planned, starting, active, stopping, stopped, failed,
  rollbackPending, rollbackFailed, interrupted,
}

/// Immutable, versioned lifecycle checkpoint for one plugin.
class PluginLifecycleCheckpoint {
  static const int currentSchemaVersion = 1;
  final int schemaVersion;
  final String pluginId;
  final String operationId;
  final PluginLifecycleOperation operation;
  final PluginLifecycleCheckpointState state;
  final int sequence;
  final int attempt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> dependencyIds;

  /// Sanitized host-classified failure information; never store secrets.
  final String? failureCode;
  final String? failureSummary;

  PluginLifecycleCheckpoint({
    this.schemaVersion = currentSchemaVersion,
    required this.pluginId,
    required this.operationId,
    required this.operation,
    required this.state,
    required this.sequence,
    required this.attempt,
    required this.createdAt,
    required this.updatedAt,
    Iterable<String> dependencyIds = const [],
    this.failureCode,
    this.failureSummary,
  }) : dependencyIds = List<String>.unmodifiable(dependencyIds) {
    if (schemaVersion < 1) throw ArgumentError.value(schemaVersion, 'schemaVersion');
    if (pluginId.trim().isEmpty) throw ArgumentError.value(pluginId, 'pluginId');
    if (operationId.trim().isEmpty) throw ArgumentError.value(operationId, 'operationId');
    if (sequence < 0) throw ArgumentError.value(sequence, 'sequence');
    if (attempt < 1) throw ArgumentError.value(attempt, 'attempt');
    if (updatedAt.isBefore(createdAt)) {
      throw ArgumentError('updatedAt must not be before createdAt');
    }
    if (this.dependencyIds.any((id) => id.trim().isEmpty)) {
      throw ArgumentError.value(dependencyIds, 'dependencyIds');
    }
  }

  bool get requiresRecovery =>
      state == PluginLifecycleCheckpointState.starting ||
      state == PluginLifecycleCheckpointState.stopping ||
      state == PluginLifecycleCheckpointState.rollbackPending;
}

/// Host-provided persistence boundary. Implementations should atomically
/// replace a plugin record and document durability/concurrency guarantees.
abstract interface class PluginLifecycleCheckpointStore {
  Future<PluginLifecycleCheckpoint?> read(String pluginId);
  Future<List<PluginLifecycleCheckpoint>> readAll();
  Future<void> write(PluginLifecycleCheckpoint checkpoint);
  Future<void> delete(String pluginId);
}

/// Ephemeral reference implementation for tests; not crash durable.
class InMemoryPluginLifecycleCheckpointStore
    implements PluginLifecycleCheckpointStore {
  final Map<String, PluginLifecycleCheckpoint> _checkpoints = {};

  @override
  Future<PluginLifecycleCheckpoint?> read(String pluginId) async =>
      _checkpoints[pluginId];

  @override
  Future<List<PluginLifecycleCheckpoint>> readAll() async =>
      List<PluginLifecycleCheckpoint>.unmodifiable(_checkpoints.values);

  @override
  Future<void> write(PluginLifecycleCheckpoint checkpoint) async {
    final current = _checkpoints[checkpoint.pluginId];
    if (current != null && checkpoint.sequence <= current.sequence) {
      throw StateError('Checkpoint sequence for "${checkpoint.pluginId}" '
          'must increase beyond ${current.sequence}.');
    }
    _checkpoints[checkpoint.pluginId] = checkpoint;
  }

  @override
  Future<void> delete(String pluginId) async {
    _checkpoints.remove(pluginId);
  }
}
