import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

PluginLifecycleCheckpoint _checkpoint(
  String id, {
  String operationId = 'old-op',
  int sequence = 3,
  PluginLifecycleCheckpointState state = PluginLifecycleCheckpointState.starting,
}) {
  final now = DateTime.utc(2026, 11, 13);
  return PluginLifecycleCheckpoint(
    pluginId: id,
    operationId: operationId,
    operation: PluginLifecycleOperation.startup,
    state: state,
    sequence: sequence,
    attempt: 1,
    createdAt: now,
    updatedAt: now,
  );
}

PluginLifecycleRecoveryJob _job({
  PluginRecoveryJobStatus status = PluginRecoveryJobStatus.planned,
  List<PluginRecoveryJobStep>? steps,
}) {
  final now = DateTime.utc(2026, 11, 13);
  return PluginLifecycleRecoveryJob(
    jobId: 'job-1',
    idempotencyKey: 'idem-1',
    operationId: 'batch-op-1',
    action: PluginRecoveryJobAction.resumeStartup,
    orderedPluginIds: ['core', 'app'],
    steps: steps ?? const [
      PluginRecoveryJobStep(
        pluginId: 'core',
        ordinal: 0,
        expectedCheckpointOperationId: 'old-op',
        expectedCheckpointSequence: 3,
      ),
      PluginRecoveryJobStep(
        pluginId: 'app',
        ordinal: 1,
        expectedCheckpointOperationId: 'old-op',
        expectedCheckpointSequence: 3,
      ),
    ],
    status: status,
    revision: 1,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('PluginLifecycleRecoveryJobStore', () {
    test('inserts once by job ID and idempotency key', () async {
      final store = InMemoryPluginLifecycleRecoveryJobStore();
      expect(await store.insertIfAbsent(_job()), isTrue);
      expect(await store.insertIfAbsent(_job()), isFalse);
      final duplicateKey = PluginLifecycleRecoveryJob.planned(
        jobId: 'job-2',
        idempotencyKey: 'idem-1',
        operationId: 'batch-op-2',
        action: PluginRecoveryJobAction.resumeStartup,
        orderedPluginIds: ['core'],
        at: DateTime.utc(2026, 11, 13),
      );
      expect(await store.insertIfAbsent(duplicateKey), isFalse);
    });

    test('compare-and-set rejects stale revisions and immutable intent changes', () async {
      final store = InMemoryPluginLifecycleRecoveryJobStore();
      final initial = _job();
      await store.insertIfAbsent(initial);
      final replacement = initial.next(
        status: PluginRecoveryJobStatus.running,
        at: DateTime.utc(2026, 11, 13, 1),
        steps: initial.steps,
      );
      expect(await store.compareAndSet(
        jobId: initial.jobId,
        expectedRevision: 1,
        replacement: replacement,
      ), isTrue);
      expect(await store.compareAndSet(
        jobId: initial.jobId,
        expectedRevision: 1,
        replacement: replacement,
      ), isFalse);
      final alteredIntent = PluginLifecycleRecoveryJob(
        jobId: replacement.jobId,
        idempotencyKey: replacement.idempotencyKey,
        operationId: replacement.operationId,
        action: PluginRecoveryJobAction.compensateShutdown,
        orderedPluginIds: replacement.orderedPluginIds,
        steps: replacement.steps,
        status: PluginRecoveryJobStatus.running,
        revision: 3,
        createdAt: replacement.createdAt,
        updatedAt: replacement.updatedAt,
      );
      expect(await store.compareAndSet(
        jobId: initial.jobId,
        expectedRevision: 2,
        replacement: alteredIntent,
      ), isFalse);
    });
  });

  group('PluginLifecycleRecoveryJobPlanner', () {
    test('recognizes untouched steps as ready without mutating either store', () async {
      final jobs = InMemoryPluginLifecycleRecoveryJobStore();
      final checkpoints = InMemoryPluginLifecycleCheckpointStore();
      final job = _job();
      await jobs.insertIfAbsent(job);
      await checkpoints.write(_checkpoint('core'));
      await checkpoints.write(_checkpoint('app'));
      final planner = PluginLifecycleRecoveryJobPlanner(
        jobStore: jobs,
        checkpointStore: checkpoints,
      );

      final report = await planner.inspect(jobId: 'job-1', activePluginIds: []);
      expect(report.disposition, PluginRecoveryJobDisposition.readyToStart);
      expect(report.steps.map((s) => s.disposition),
          everyElement(PluginRecoveryJobStepDisposition.pending));
      expect((await jobs.read('job-1'))!.revision, 1);
      expect((await checkpoints.read('core'))!.sequence, 3);
    });

    test('never recommends replay for a running step after restart', () async {
      final jobs = InMemoryPluginLifecycleRecoveryJobStore();
      final checkpoints = InMemoryPluginLifecycleCheckpointStore();
      final now = DateTime.utc(2026, 11, 13);
      final job = _job(
        status: PluginRecoveryJobStatus.running,
        steps: [
          PluginRecoveryJobStep(
            pluginId: 'core',
            ordinal: 0,
            status: PluginRecoveryJobStepStatus.running,
            expectedCheckpointOperationId: 'old-op',
            expectedCheckpointSequence: 3,
            executionOperationId: 'exec-core',
            startedAt: now,
          ),
          PluginRecoveryJobStep(
            pluginId: 'app',
            ordinal: 1,
            expectedCheckpointOperationId: 'old-op',
            expectedCheckpointSequence: 3,
          ),
        ],
      );
      await jobs.insertIfAbsent(job);
      await checkpoints.write(_checkpoint(
        'core',
        operationId: 'exec-core',
        sequence: 5,
        state: PluginLifecycleCheckpointState.starting,
      ));
      await checkpoints.write(_checkpoint('app'));
      final planner = PluginLifecycleRecoveryJobPlanner(
        jobStore: jobs,
        checkpointStore: checkpoints,
      );

      final report = await planner.inspect(jobId: 'job-1', activePluginIds: []);
      expect(report.disposition, PluginRecoveryJobDisposition.interruptedNeedsInspection);
      expect(report.steps.first.disposition,
          PluginRecoveryJobStepDisposition.runningNeedsInspection);
      expect(report.steps.last.disposition, PluginRecoveryJobStepDisposition.pending);
      expect((await jobs.read('job-1'))!.status, PluginRecoveryJobStatus.running);
      expect((await checkpoints.read('core'))!.state,
          PluginLifecycleCheckpointState.starting);
    });

    test('verifies completed steps against checkpoint and live active state', () async {
      final jobs = InMemoryPluginLifecycleRecoveryJobStore();
      final checkpoints = InMemoryPluginLifecycleCheckpointStore();
      final now = DateTime.utc(2026, 11, 13);
      final job = _job(
        status: PluginRecoveryJobStatus.completed,
        steps: [
          PluginRecoveryJobStep(
            pluginId: 'core',
            ordinal: 0,
            status: PluginRecoveryJobStepStatus.completed,
            expectedCheckpointOperationId: 'old-op',
            expectedCheckpointSequence: 3,
            executionOperationId: 'exec-core',
            startedAt: now,
            completedAt: now.add(const Duration(seconds: 1)),
          ),
          PluginRecoveryJobStep(
            pluginId: 'app',
            ordinal: 1,
            status: PluginRecoveryJobStepStatus.completed,
            expectedCheckpointOperationId: 'old-op',
            expectedCheckpointSequence: 3,
            executionOperationId: 'exec-app',
            startedAt: now,
            completedAt: now.add(const Duration(seconds: 1)),
          ),
        ],
      );
      await jobs.insertIfAbsent(job);
      await checkpoints.write(_checkpoint(
        'core',
        operationId: 'exec-core',
        sequence: 5,
        state: PluginLifecycleCheckpointState.active,
      ));
      await checkpoints.write(_checkpoint(
        'app',
        operationId: 'exec-app',
        sequence: 5,
        state: PluginLifecycleCheckpointState.active,
      ));
      final planner = PluginLifecycleRecoveryJobPlanner(
        jobStore: jobs,
        checkpointStore: checkpoints,
      );

      final report = await planner.inspect(
        jobId: 'job-1',
        activePluginIds: ['core', 'app'],
      );
      expect(report.disposition, PluginRecoveryJobDisposition.completed);
      expect(report.steps.map((s) => s.disposition),
          everyElement(PluginRecoveryJobStepDisposition.completedAndVerified));
    });
  });
}
