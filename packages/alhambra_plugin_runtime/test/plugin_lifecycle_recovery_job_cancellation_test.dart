import 'dart:async';

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


class _RecoveryPlugin implements AlhambraPlugin {
  _RecoveryPlugin(this.id);
  final String id;
  int activations = 0;
  @override
  PluginMetadata get metadata => PluginMetadata(id: id, name: id, version: '1.0.0');
  @override
  Future<void> activate(PluginContext context) async { activations++; }
  @override
  Future<void> deactivate(PluginContext context) async {}
}

class _RecoveryExecutor implements PluginLifecycleRecoveryExecutor {
  _RecoveryExecutor(this.callback);
  final Future<void> Function(PluginLifecycleRecoveryExecutionContext) callback;
  @override
  Future<void> execute(PluginLifecycleRecoveryExecutionContext context) => callback(context);
}

PluginLifecycleCheckpoint _checkpoint(String id, {List<String> dependencies = const []}) {
  final now = DateTime.utc(2026, 11, 14);
  return PluginLifecycleCheckpoint(
    pluginId: id,
    operationId: 'old-$id',
    operation: PluginLifecycleOperation.startup,
    state: PluginLifecycleCheckpointState.starting,
    sequence: 2,
    attempt: 1,
    createdAt: now,
    updatedAt: now,
    dependencyIds: dependencies,
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

    test('running cancellation waits for the in-flight step then skips later steps', () async {
      final checkpoints = InMemoryPluginLifecycleCheckpointStore();
      await checkpoints.write(_checkpoint('core'));
      await checkpoints.write(_checkpoint('app', dependencies: ['core']));
      final jobs = InMemoryPluginLifecycleRecoveryJobStore();
      final now = DateTime.utc(2026, 11, 14);
      final job = PluginLifecycleRecoveryJob.planned(
        jobId: 'job-running-cancel',
        idempotencyKey: 'idem-running-cancel',
        operationId: 'batch-running-cancel',
        action: PluginRecoveryJobAction.resumeStartup,
        orderedPluginIds: ['core', 'app'],
        steps: [
          PluginRecoveryJobStep(pluginId: 'core', ordinal: 0,
            expectedCheckpointOperationId: 'old-core',
            expectedCheckpointSequence: 2, executionOperationId: 'exec-core'),
          PluginRecoveryJobStep(pluginId: 'app', ordinal: 1,
            expectedCheckpointOperationId: 'old-app',
            expectedCheckpointSequence: 2, executionOperationId: 'exec-app'),
        ],
        at: now,
      );
      await jobs.insertIfAbsent(job);
      final entered = Completer<void>();
      final release = Completer<void>();
      final core = _RecoveryPlugin('core');
      final app = _RecoveryPlugin('app');
      final runner = PluginLifecycleRecoveryRunner(
        store: checkpoints,
        manager: PluginManager(),
        executor: _RecoveryExecutor((context) async {
          if (context.plugin.metadata.id == 'core') {
            entered.complete();
            await release.future;
          }
          await context.resumeStartup();
        }),
      );
      final execution = runner.executeBatchWithJob(
        request: PluginLifecycleRecoveryBatchRequest(
          pluginIds: ['app', 'core'],
          action: PluginLifecycleRecoveryExecutionAction.resumeStartup,
          compiledPlugins: {'core': core, 'app': app},
          operationIdFactory: (id) => 'exec-$id',
        ),
        jobStore: jobs,
        jobId: job.jobId,
      );
      await entered.future;
      final running = (await jobs.read(job.jobId))!;
      final requested = await PluginLifecycleRecoveryJobCancellationController(
        store: jobs,
      ).requestCancellation(
        jobId: job.jobId,
        expectedRevision: running.revision,
      );
      expect(requested.status, PluginRecoveryJobStatus.cancellationRequested);
      release.complete();

      final report = await execution;
      final persisted = (await jobs.read(job.jobId))!;
      expect(report.succeeded, isFalse);
      expect(persisted.status, PluginRecoveryJobStatus.cancelled);
      expect(persisted.steps[0].status, PluginRecoveryJobStepStatus.completed);
      expect(persisted.steps[1].status, PluginRecoveryJobStepStatus.skipped);
      expect(core.activations, 1);
      expect(app.activations, 0);
    });

    test('restart inspection treats a cancellation request as host action', () async {
      final jobs = InMemoryPluginLifecycleRecoveryJobStore();
      final checkpoints = InMemoryPluginLifecycleCheckpointStore();
      final base = PluginLifecycleRecoveryJob.planned(
        jobId: 'job-inspect-cancel',
        idempotencyKey: 'idem-inspect-cancel',
        operationId: 'batch-inspect-cancel',
        action: PluginRecoveryJobAction.resumeStartup,
        orderedPluginIds: ['core'],
        at: DateTime.utc(2026, 11, 14),
      );
      final requested = base.next(
        status: PluginRecoveryJobStatus.cancellationRequested,
        at: DateTime.utc(2026, 11, 14, 1),
        cancellationRequestedAt: DateTime.utc(2026, 11, 14, 1),
        steps: base.steps,
      );
      await jobs.insertIfAbsent(requested);
      final report = await PluginLifecycleRecoveryJobPlanner(
        jobStore: jobs,
        checkpointStore: checkpoints,
      ).inspect(jobId: requested.jobId, activePluginIds: []);
      expect(report.disposition, PluginRecoveryJobDisposition.interruptedNeedsInspection);
      expect(report.requiresHostAction, isTrue);
    });
  });
}
