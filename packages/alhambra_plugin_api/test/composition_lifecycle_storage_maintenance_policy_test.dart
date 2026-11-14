import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:test/test.dart';

void main() {
  final planner = CompositionLifecycleStorageMaintenancePlanner();
  final now = DateTime.utc(2026, 11, 14, 10);

  CompositionLifecycleStorageHealth health({
    int? recordCount = 10,
    int? primaryBytes = 100,
    int? auxiliaryBytes = 20,
  }) =>
      CompositionLifecycleStorageHealth(
        state: CompositionLifecycleStorageHealthState.healthy,
        checkedAt: now,
        recordCount: recordCount,
        primaryStorageBytes: primaryBytes,
        auxiliaryStorageBytes: auxiliaryBytes,
      );

  test('requires at least one threshold and validates limits', () {
    expect(
      () => CompositionLifecycleStorageMaintenancePolicy(),
      throwsArgumentError,
    );
    expect(
      () => CompositionLifecycleStorageMaintenancePolicy(maxEvents: 0),
      throwsArgumentError,
    );
    expect(
      () => CompositionLifecycleStorageMaintenancePolicy(
        maxEvents: 10,
        minimumInterval: const Duration(seconds: -1),
      ),
      throwsArgumentError,
    );
  });

  test('plans a retention sweep with an inclusive cutoff and checkpoint', () {
    final plan = planner.evaluate(
      policy: const CompositionLifecycleStorageMaintenancePolicy(
        retentionAge: Duration(days: 30),
      ),
      health: health(),
      evaluatedAt: now,
    );

    expect(plan.due, isTrue);
    expect(plan.actionable, isTrue);
    expect(plan.reasons, [
      CompositionLifecycleStorageMaintenanceReason.retentionSweep,
    ]);
    expect(plan.request!.retainFrom, now.subtract(const Duration(days: 30)));
    expect(plan.request!.checkpoint, isTrue);
  });

  test('triggers event count only when a known count exceeds the limit', () {
    final policy = const CompositionLifecycleStorageMaintenancePolicy(
      maxEvents: 5,
      checkpointPolicy: CompositionLifecycleStorageCheckpointPolicy.never,
    );
    final plan = planner.evaluate(
      policy: policy,
      health: health(recordCount: 8),
      evaluatedAt: now,
    );

    expect(plan.due, isTrue);
    expect(plan.request!.maxEvents, 5);
    expect(plan.request!.checkpoint, isFalse);

    final below = planner.evaluate(
      policy: policy,
      health: health(recordCount: 5),
      evaluatedAt: now,
    );
    expect(below.due, isFalse);
  });

  test('unknown measurements are not interpreted as zero', () {
    final plan = planner.evaluate(
      policy: const CompositionLifecycleStorageMaintenancePolicy(
        maxEvents: 5,
        maxStorageBytes: 100,
      ),
      health: health(recordCount: null, primaryBytes: null, auxiliaryBytes: 10),
      evaluatedAt: now,
    );

    expect(plan.due, isFalse);
    expect(plan.unavailableMetrics, [
      'recordCount',
      'primaryStorageBytes',
    ]);
  });

  test('storage threshold is evaluated from both reported footprints', () {
    final plan = planner.evaluate(
      policy: const CompositionLifecycleStorageMaintenancePolicy(
        maxStorageBytes: 100,
      ),
      health: health(primaryBytes: 80, auxiliaryBytes: 30),
      evaluatedAt: now,
    );

    expect(plan.due, isTrue);
    expect(
      plan.reasons,
      [CompositionLifecycleStorageMaintenanceReason.storageFootprintExceeded],
    );
    expect(plan.request!.checkpoint, isTrue);
  });

  test('minimum interval blocks execution but preserves trigger reasons', () {
    final plan = planner.evaluate(
      policy: const CompositionLifecycleStorageMaintenancePolicy(
        retentionAge: Duration(days: 7),
        minimumInterval: Duration(hours: 6),
      ),
      health: health(),
      evaluatedAt: now,
      lastMaintenanceAt: now.subtract(const Duration(hours: 2)),
    );

    expect(plan.due, isFalse);
    expect(plan.blockedByMinimumInterval, isTrue);
    expect(plan.nextEligibleAt, now.add(const Duration(hours: 4)));
    expect(plan.reasons, [
      CompositionLifecycleStorageMaintenanceReason.retentionSweep,
    ]);
    expect(plan.request, isNull);
  });

  test('disabled checkpointing can expose a due but non-actionable plan', () {
    final plan = planner.evaluate(
      policy: const CompositionLifecycleStorageMaintenancePolicy(
        maxStorageBytes: 100,
        checkpointPolicy: CompositionLifecycleStorageCheckpointPolicy.never,
      ),
      health: health(primaryBytes: 90, auxiliaryBytes: 20),
      evaluatedAt: now,
    );

    expect(plan.due, isTrue);
    expect(plan.actionable, isFalse);
    expect(plan.request, isNull);
  });

  test('plan reason collections are immutable', () {
    final plan = planner.evaluate(
      policy: const CompositionLifecycleStorageMaintenancePolicy(
        retentionAge: Duration(days: 1),
      ),
      health: health(),
      evaluatedAt: now,
    );

    expect(
      () => plan.reasons.add(
        CompositionLifecycleStorageMaintenanceReason.eventCountExceeded,
      ),
      throwsUnsupportedError,
    );
  });
}
