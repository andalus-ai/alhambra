/// Backend-neutral policy and deterministic planning for lifecycle storage
/// maintenance.
///
/// The planner is intentionally pure: it does not inspect a store, schedule a
/// timer, authorize an operation, or execute a maintenance request. A host
/// should supply a fresh health snapshot and its own maintenance history.
enum CompositionLifecycleStorageCheckpointPolicy {
  /// Never add a checkpoint to a generated request.
  never,

  /// Add a checkpoint whenever at least one policy threshold is due.
  whenMaintenanceIsDue,
}

/// Declarative thresholds for lifecycle storage maintenance.
///
/// [retentionAge] requests a periodic retention sweep. Since the health
/// contract does not promise an oldest-event timestamp, the planner does not
/// pretend it can prove whether old records exist: it emits the inclusive
/// [retainFrom] cutoff whenever the policy is due.
///
/// [maxStorageBytes] is evaluated only when both primary and auxiliary storage
/// measurements are available. Unknown measurements are never treated as
/// zero. A storage-footprint threshold is a trigger, not a promise that a
/// checkpoint or compaction will reclaim that exact number of bytes.
final class CompositionLifecycleStorageMaintenancePolicy {
  final Duration? retentionAge;
  final int? maxEvents;
  final int? maxStorageBytes;
  final Duration minimumInterval;
  final CompositionLifecycleStorageCheckpointPolicy checkpointPolicy;

  const CompositionLifecycleStorageMaintenancePolicy({
    this.retentionAge,
    this.maxEvents,
    this.maxStorageBytes,
    this.minimumInterval = Duration.zero,
    this.checkpointPolicy =
        CompositionLifecycleStorageCheckpointPolicy.whenMaintenanceIsDue,
  }) {
    if (retentionAge != null && retentionAge.inMicroseconds <= 0) {
      throw ArgumentError.value(
        retentionAge,
        'retentionAge',
        'Must be greater than zero.',
      );
    }
    if (maxEvents != null && maxEvents! < 1) {
      throw ArgumentError.value(maxEvents, 'maxEvents', 'Must be greater than zero.');
    }
    if (maxStorageBytes != null && maxStorageBytes! < 1) {
      throw ArgumentError.value(
        maxStorageBytes,
        'maxStorageBytes',
        'Must be greater than zero.',
      );
    }
    if (minimumInterval.isNegative) {
      throw ArgumentError.value(
        minimumInterval,
        'minimumInterval',
        'Must not be negative.',
      );
    }
    if (retentionAge == null && maxEvents == null && maxStorageBytes == null) {
      throw ArgumentError(
        'At least one maintenance threshold must be configured.',
      );
    }
  }
}

/// Reasons that caused a maintenance policy to become due.
enum CompositionLifecycleStorageMaintenanceReason {
  retentionSweep,
  eventCountExceeded,
  storageFootprintExceeded,
}

/// Deterministic result of evaluating a maintenance policy against one health
/// snapshot and the host's last successful maintenance time.
final class CompositionLifecycleStorageMaintenancePlan {
  final DateTime evaluatedAt;
  final bool due;
  final List<CompositionLifecycleStorageMaintenanceReason> reasons;
  final List<String> unavailableMetrics;
  final DateTime? nextEligibleAt;
  final CompositionLifecycleStorageMaintenanceRequest? request;
  final bool blockedByMinimumInterval;

  CompositionLifecycleStorageMaintenancePlan({
    required this.evaluatedAt,
    required this.due,
    required List<CompositionLifecycleStorageMaintenanceReason> reasons,
    required List<String> unavailableMetrics,
    this.nextEligibleAt,
    this.request,
    required this.blockedByMinimumInterval,
  })  : reasons = List.unmodifiable(reasons),
        unavailableMetrics = List.unmodifiable(unavailableMetrics) {
    if (due && reasons.isEmpty) {
      throw ArgumentError('A due plan must include at least one reason.');
    }
    if (blockedByMinimumInterval && due) {
      throw ArgumentError('A plan blocked by the minimum interval cannot be due.');
    }
    if (request != null && !due) {
      throw ArgumentError('A maintenance request requires a due plan.');
    }
  }

  /// Whether the plan contains an executable request.
  ///
  /// A storage-footprint threshold can be due without an executable request
  /// when checkpointing is disabled and no retention/count action is
  /// configured. Hosts can surface that condition for operator review.
  bool get actionable => request != null;
}

/// Pure evaluator for [CompositionLifecycleStorageMaintenancePolicy].
final class CompositionLifecycleStorageMaintenancePlanner {
  const CompositionLifecycleStorageMaintenancePlanner();

  CompositionLifecycleStorageMaintenancePlan evaluate({
    required CompositionLifecycleStorageMaintenancePolicy policy,
    required CompositionLifecycleStorageHealth health,
    required DateTime evaluatedAt,
    DateTime? lastMaintenanceAt,
  }) {
    final now = evaluatedAt.toUtc();
    final reasons = <CompositionLifecycleStorageMaintenanceReason>[];
    final unavailable = <String>[];
    DateTime? retainFrom;

    if (policy.retentionAge != null) {
      reasons.add(CompositionLifecycleStorageMaintenanceReason.retentionSweep);
      retainFrom = now.subtract(policy.retentionAge!);
    }

    if (policy.maxEvents != null) {
      final count = health.recordCount;
      if (count == null) {
        unavailable.add('recordCount');
      } else if (count > policy.maxEvents!) {
        reasons.add(CompositionLifecycleStorageMaintenanceReason.eventCountExceeded);
      }
    }

    if (policy.maxStorageBytes != null) {
      final primary = health.primaryStorageBytes;
      final auxiliary = health.auxiliaryStorageBytes;
      if (primary == null || auxiliary == null) {
        if (primary == null) unavailable.add('primaryStorageBytes');
        if (auxiliary == null) unavailable.add('auxiliaryStorageBytes');
      } else if (primary + auxiliary > policy.maxStorageBytes!) {
        reasons.add(
          CompositionLifecycleStorageMaintenanceReason.storageFootprintExceeded,
        );
      }
    }

    if (reasons.isEmpty) {
      return CompositionLifecycleStorageMaintenancePlan(
        evaluatedAt: now,
        due: false,
        reasons: reasons,
        unavailableMetrics: unavailable,
        blockedByMinimumInterval: false,
      );
    }

    DateTime? nextEligibleAt;
    final interval = policy.minimumInterval;
    if (lastMaintenanceAt != null) {
      nextEligibleAt = lastMaintenanceAt.toUtc().add(interval);
      if (now.isBefore(nextEligibleAt)) {
        return CompositionLifecycleStorageMaintenancePlan(
          evaluatedAt: now,
          due: false,
          reasons: reasons,
          unavailableMetrics: unavailable,
          nextEligibleAt: nextEligibleAt,
          blockedByMinimumInterval: true,
        );
      }
    }

    final requestCheckpoint = policy.checkpointPolicy ==
        CompositionLifecycleStorageCheckpointPolicy.whenMaintenanceIsDue;
    final hasRetentionOrCountAction =
        retainFrom != null ||
        (policy.maxEvents != null &&
            health.recordCount != null &&
            health.recordCount! > policy.maxEvents!);
    final hasCheckpointAction = requestCheckpoint;

    final request = hasRetentionOrCountAction || hasCheckpointAction
        ? CompositionLifecycleStorageMaintenanceRequest(
            retainFrom: retainFrom,
            maxEvents: hasRetentionOrCountAction &&
                    policy.maxEvents != null &&
                    health.recordCount != null &&
                    health.recordCount! > policy.maxEvents!
                ? policy.maxEvents
                : null,
            checkpoint: requestCheckpoint,
          )
        : null;

    return CompositionLifecycleStorageMaintenancePlan(
      evaluatedAt: now,
      due: true,
      reasons: reasons,
      unavailableMetrics: unavailable,
      nextEligibleAt: nextEligibleAt,
      request: request,
      blockedByMinimumInterval: false,
    );
  }
}
