/// Durable, host-persisted intent and progress for a multi-plugin recovery job.
///
/// This is a persistence-neutral aggregate. It contains identifiers and
/// sanitized outcomes only; never serialize plugin instances, credentials,
/// configuration, or arbitrary executor state.
enum PluginRecoveryJobAction { resumeStartup, compensateShutdown }

enum PluginRecoveryJobStatus {
  planned,
  running,
  partiallyCompleted,
  completed,
  failed,
  interrupted,
  manualReview,
  cancelled,
}

enum PluginRecoveryJobStepStatus {
  pending,
  running,
  completed,
  failed,
  skipped,
}

final class PluginRecoveryJobStep {
  final String pluginId;
  final int ordinal;
  final PluginRecoveryJobStepStatus status;
  final String? expectedCheckpointOperationId;
  final int? expectedCheckpointSequence;
  final String? executionOperationId;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? failureCode;
  final String? failureSummary;

  PluginRecoveryJobStep({
    required this.pluginId,
    required this.ordinal,
    this.status = PluginRecoveryJobStepStatus.pending,
    this.expectedCheckpointOperationId,
    this.expectedCheckpointSequence,
    this.executionOperationId,
    this.startedAt,
    this.completedAt,
    this.failureCode,
    this.failureSummary,
  }) {
    if (pluginId.trim().isEmpty) throw ArgumentError.value(pluginId, 'pluginId');
    if (ordinal < 0) throw ArgumentError.value(ordinal, 'ordinal');
    if (expectedCheckpointSequence != null && expectedCheckpointSequence! < 0) {
      throw ArgumentError.value(expectedCheckpointSequence, 'expectedCheckpointSequence');
    }
    if (startedAt != null && completedAt != null && completedAt!.isBefore(startedAt!)) {
      throw ArgumentError('completedAt must not precede startedAt');
    }
    if (status == PluginRecoveryJobStepStatus.running && startedAt == null) {
      throw ArgumentError('A running step requires startedAt.');
    }
    if (status == PluginRecoveryJobStepStatus.completed && completedAt == null) {
      throw ArgumentError('A completed step requires completedAt.');
    }
    if (status == PluginRecoveryJobStepStatus.failed &&
        (failureSummary == null || failureSummary!.trim().isEmpty)) {
      throw ArgumentError('A failed step requires a sanitized failureSummary.');
    }
  }

  PluginRecoveryJobStep copyWith({
    PluginRecoveryJobStepStatus? status,
    String? expectedCheckpointOperationId,
    int? expectedCheckpointSequence,
    String? executionOperationId,
    DateTime? startedAt,
    DateTime? completedAt,
    String? failureCode,
    String? failureSummary,
  }) => PluginRecoveryJobStep(
    pluginId: pluginId,
    ordinal: ordinal,
    status: status ?? this.status,
    expectedCheckpointOperationId: expectedCheckpointOperationId ?? this.expectedCheckpointOperationId,
    expectedCheckpointSequence: expectedCheckpointSequence ?? this.expectedCheckpointSequence,
    executionOperationId: executionOperationId ?? this.executionOperationId,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt ?? this.completedAt,
    failureCode: failureCode,
    failureSummary: failureSummary,
  );
}

/// Versioned aggregate for one explicitly authorized recovery batch.
final class PluginLifecycleRecoveryJob {
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String jobId;
  final String idempotencyKey;
  final String operationId;
  final PluginRecoveryJobAction action;
  final List<String> orderedPluginIds;
  final List<PluginRecoveryJobStep> steps;
  final PluginRecoveryJobStatus status;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? initiatedBy;
  final String? correlationId;
  final String? failureCode;
  final String? failureSummary;

  PluginLifecycleRecoveryJob({
    this.schemaVersion = currentSchemaVersion,
    required this.jobId,
    required this.idempotencyKey,
    required this.operationId,
    required this.action,
    required Iterable<String> orderedPluginIds,
    required Iterable<PluginRecoveryJobStep> steps,
    required this.status,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.initiatedBy,
    this.correlationId,
    this.failureCode,
    this.failureSummary,
  })  : orderedPluginIds = List<String>.unmodifiable(orderedPluginIds),
        steps = List<PluginRecoveryJobStep>.unmodifiable(steps) {
    if (schemaVersion < 1) throw ArgumentError.value(schemaVersion, 'schemaVersion');
    for (final value in [jobId, idempotencyKey, operationId]) {
      if (value.trim().isEmpty) throw ArgumentError('Job identity fields must not be empty.');
    }
    if (this.orderedPluginIds.isEmpty ||
        this.orderedPluginIds.any((id) => id.trim().isEmpty) ||
        this.orderedPluginIds.toSet().length != this.orderedPluginIds.length) {
      throw ArgumentError('orderedPluginIds must contain unique, non-empty IDs.');
    }
    if (revision < 1) throw ArgumentError.value(revision, 'revision');
    if (updatedAt.isBefore(createdAt)) throw ArgumentError('updatedAt precedes createdAt');
    if (this.steps.length != this.orderedPluginIds.length) {
      throw ArgumentError('A recovery job requires exactly one step per plugin.');
    }
    for (var i = 0; i < this.steps.length; i++) {
      if (this.steps[i].pluginId != this.orderedPluginIds[i] ||
          this.steps[i].ordinal != i) {
        throw ArgumentError('Recovery steps must match the ordered plugin IDs and ordinals.');
      }
    }
    if (status == PluginRecoveryJobStatus.failed &&
        (failureSummary == null || failureSummary!.trim().isEmpty)) {
      throw ArgumentError('A failed job requires a sanitized failureSummary.');
    }
  }

  factory PluginLifecycleRecoveryJob.planned({
    required String jobId,
    required String idempotencyKey,
    required String operationId,
    required PluginRecoveryJobAction action,
    required Iterable<String> orderedPluginIds,
    required DateTime at,
    String? initiatedBy,
    String? correlationId,
  }) {
    final ids = orderedPluginIds.toList(growable: false);
    final timestamp = at.toUtc();
    return PluginLifecycleRecoveryJob(
      jobId: jobId,
      idempotencyKey: idempotencyKey,
      operationId: operationId,
      action: action,
      orderedPluginIds: ids,
      steps: _pendingSteps(ids),
      status: PluginRecoveryJobStatus.planned,
      revision: 1,
      createdAt: timestamp,
      updatedAt: timestamp,
      initiatedBy: initiatedBy,
      correlationId: correlationId,
    );
  }

  PluginLifecycleRecoveryJob next({
    required PluginRecoveryJobStatus status,
    required DateTime at,
    required Iterable<PluginRecoveryJobStep> steps,
    String? failureCode,
    String? failureSummary,
  }) {
    final instant = at.toUtc();
    return PluginLifecycleRecoveryJob(
      schemaVersion: schemaVersion,
      jobId: jobId,
      idempotencyKey: idempotencyKey,
      operationId: operationId,
      action: action,
      orderedPluginIds: orderedPluginIds,
      steps: steps,
      status: status,
      revision: revision + 1,
      createdAt: createdAt,
      updatedAt: instant.isBefore(updatedAt) ? updatedAt : instant,
      initiatedBy: initiatedBy,
      correlationId: correlationId,
      failureCode: failureCode,
      failureSummary: failureSummary,
    );
  }

  static List<PluginRecoveryJobStep> _pendingSteps(Iterable<String> ids) {
    final values = ids.toList(growable: false);
    return List.generate(values.length, (i) =>
      PluginRecoveryJobStep(pluginId: values[i], ordinal: i));
  }
}

/// Atomic aggregate persistence boundary.
///
/// Production adapters must implement insertIfAbsent and compareAndSet with
/// transactional/linearizable semantics across every process that can update
/// the same job. In-memory storage is only a single-isolate reference store.
abstract interface class PluginLifecycleRecoveryJobStore {
  Future<PluginLifecycleRecoveryJob?> read(String jobId);
  Future<List<PluginLifecycleRecoveryJob>> readAll();
  Future<bool> insertIfAbsent(PluginLifecycleRecoveryJob job);
  Future<bool> compareAndSet({
    required String jobId,
    required int expectedRevision,
    required PluginLifecycleRecoveryJob replacement,
  });
}

final class InMemoryPluginLifecycleRecoveryJobStore
    implements PluginLifecycleRecoveryJobStore {
  final Map<String, PluginLifecycleRecoveryJob> _jobs = {};

  @override
  Future<PluginLifecycleRecoveryJob?> read(String jobId) async => _jobs[jobId];

  @override
  Future<List<PluginLifecycleRecoveryJob>> readAll() async =>
      List<PluginLifecycleRecoveryJob>.unmodifiable(
        _jobs.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      );

  @override
  Future<bool> insertIfAbsent(PluginLifecycleRecoveryJob job) async {
    if (_jobs.containsKey(job.jobId) ||
        _jobs.values.any((existing) => existing.idempotencyKey == job.idempotencyKey)) {
      return false;
    }
    _jobs[job.jobId] = job;
    return true;
  }

  @override
  Future<bool> compareAndSet({
    required String jobId,
    required int expectedRevision,
    required PluginLifecycleRecoveryJob replacement,
  }) async {
    final current = _jobs[jobId];
    if (current == null ||
        current.revision != expectedRevision ||
        replacement.revision != expectedRevision + 1 ||
        replacement.jobId != jobId ||
        replacement.idempotencyKey != current.idempotencyKey ||
        replacement.operationId != current.operationId ||
        replacement.action != current.action ||
        replacement.schemaVersion != current.schemaVersion ||
        replacement.initiatedBy != current.initiatedBy ||
        replacement.correlationId != current.correlationId ||
        !_samePluginIds(replacement.orderedPluginIds, current.orderedPluginIds) ||
        replacement.createdAt != current.createdAt) {
      return false;
    }
    _jobs[jobId] = replacement;
    return true;
  }
}


bool _samePluginIds(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}
