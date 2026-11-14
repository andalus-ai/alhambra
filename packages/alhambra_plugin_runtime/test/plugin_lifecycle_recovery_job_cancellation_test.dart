import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

PluginLifecycleRecoveryJob _job({
  PluginRecoveryJobStatus status = PluginRecoveryJobStatus.planned,
  List<PluginRecoveryJobStep>? steps,
}) {
  final now = DateTime.utc(2026, 11, 14);
  return PluginLifecycleRecoveryJob.planned(
    jobId: 'job-cancel',
    idempotencyKey: 'idem-cancel',
    operationId: 'batch-cancel',
    action: PluginRecoveryJobAction.resumeStartup,
    orderedPluginIds: ['core', 'app'],
    steps: steps,
    at: now,
  ).next(
    status: status,
    at: now.add(const Duration(seconds: 1)),
    steps: steps ?? [
      PluginRecoveryJobStep(pluginId: 'core', ordinal: 0),
      PluginRecoveryJobStep(pluginId: 'app', ordinal: 1),
    ],
  );
}

void main() {
  group('PluginLifecycleRecoveryJobCancellationController', () {
    test('cancels a planned job immediately and marks all steps skipped', () async {
      final store = InMemoryPluginLifecycleRecoveryJobStore();
      final job = PluginLifecycleRecoveryJob.planned(
        jobId: 'job-cancel',
        idempotencyKey: 'idem-cancel',
        operationId: 'batch-cancel',
        action: PluginRecoveryJobAction.resumeStartup,
        orderedPluginIds: ['core', 'app'],
        at: DateTime.utc(2026, 11, 14),
      );
      await store.insertIfAbsent(job);
      final controller = PluginLifecycleRecoveryJobCancellationController(
        store: store,
        clock: () => DateTime.utc(2026, 11, 14, 1),
      );

      final cancelled = await controller.requestCancellation(
        jobId: job.jobId,
        expectedRevision: job.revision,
      );

      expect(cancelled.status, PluginRecoveryJobStatus.cancelled);
      expect(cancelled.cancellationRequestedAt, isNotNull);
      expect(cancelled.steps.map((s) => s.status),
          everyElement(PluginRecoveryJobStepStatus.skipped));
    });

    test('marks a running job cancellation-requested without changing in-flight step', () async {
      final store = InMemoryPluginLifecycleRecoveryJobStore();
      final job = _job(status: PluginRecoveryJobStatus.running);
      await store.insertIfAbsent(job);
      final controller = PluginLifecycleRecoveryJobCancellationController(store: store);

      final requested = await controller.requestCancellation(
        jobId: job.jobId,
        expectedRevision: job.revision,
      );

      expect(requested.status, PluginRecoveryJobStatus.cancellationRequested);
      expect(requested.steps.map((s) => s.status),
          everyElement(PluginRecoveryJobStepStatus.pending));
      expect(requested.cancellationRequestedAt, isNotNull);
    });

    test('rejects stale revisions and terminal jobs', () async {
      final store = InMemoryPluginLifecycleRecoveryJobStore();
      final job = _job(status: PluginRecoveryJobStatus.completed);
      await store.insertIfAbsent(job);
      final controller = PluginLifecycleRecoveryJobCancellationController(store: store);

      await expectLater(
        controller.requestCancellation(jobId: job.jobId, expectedRevision: job.revision - 1),
        throwsStateError,
      );
      await expectLater(
        controller.requestCancellation(jobId: job.jobId, expectedRevision: job.revision),
        throwsStateError,
      );
    });
  });
}
