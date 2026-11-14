import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

class _Plugin implements AlhambraPlugin {
  _Plugin(this.id);
  final String id;
  int activations = 0;

  @override
  PluginMetadata get metadata => PluginMetadata(id: id, name: id, version: '1.0.0');

  @override
  Future<void> activate(PluginContext context) async { activations++; }

  @override
  Future<void> deactivate(PluginContext context) async {}
}

class _Executor implements PluginLifecycleRecoveryExecutor {
  _Executor(this.action);
  final Future<void> Function(PluginLifecycleRecoveryExecutionContext) action;

  @override
  Future<void> execute(PluginLifecycleRecoveryExecutionContext context) => action(context);
}

class _FailCompletedStepStore implements PluginLifecycleRecoveryJobStore {
  _FailCompletedStepStore(this.delegate);
  final InMemoryPluginLifecycleRecoveryJobStore delegate;

  @override
  Future<PluginLifecycleRecoveryJob?> read(String jobId) => delegate.read(jobId);

  @override
  Future<List<PluginLifecycleRecoveryJob>> readAll() => delegate.readAll();

  @override
  Future<bool> insertIfAbsent(PluginLifecycleRecoveryJob job) => delegate.insertIfAbsent(job);

  @override
  Future<bool> compareAndSet({
    required String jobId,
    required int expectedRevision,
    required PluginLifecycleRecoveryJob replacement,
  }) {
    if (replacement.steps.any((step) => step.status == PluginRecoveryJobStepStatus.completed)) {
      return Future.value(false);
    }
    return delegate.compareAndSet(
      jobId: jobId,
      expectedRevision: expectedRevision,
      replacement: replacement,
    );
  }
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

PluginLifecycleRecoveryJob _job() {
  final now = DateTime.utc(2026, 11, 14);
  return PluginLifecycleRecoveryJob.planned(
    jobId: 'job-1',
    idempotencyKey: 'idem-1',
    operationId: 'batch-op-1',
    action: PluginRecoveryJobAction.resumeStartup,
    orderedPluginIds: ['core', 'app'],
    steps: [
      PluginRecoveryJobStep(
        pluginId: 'core',
        ordinal: 0,
        expectedCheckpointOperationId: 'old-core',
        expectedCheckpointSequence: 2,
        executionOperationId: 'job-core',
      ),
      PluginRecoveryJobStep(
        pluginId: 'app',
        ordinal: 1,
        expectedCheckpointOperationId: 'old-app',
        expectedCheckpointSequence: 2,
        executionOperationId: 'job-app',
      ),
    ],
    at: now,
  );
}

PluginLifecycleRecoveryBatchRequest _request(_Plugin core, _Plugin app) =>
    PluginLifecycleRecoveryBatchRequest(
      pluginIds: ['app', 'core'],
      action: PluginLifecycleRecoveryExecutionAction.resumeStartup,
      compiledPlugins: {'core': core, 'app': app},
      operationIdFactory: (id) => 'job-$id',
    );

void main() {
  group('PluginLifecycleRecoveryRunner.executeBatchWithJob', () {
    test('persists intent, claims and completes every ordered step', () async {
      final checkpoints = InMemoryPluginLifecycleCheckpointStore();
      await checkpoints.write(_checkpoint('core'));
      await checkpoints.write(_checkpoint('app', dependencies: ['core']));
      final jobs = InMemoryPluginLifecycleRecoveryJobStore();
      final job = _job();
      expect(await jobs.insertIfAbsent(job), isTrue);
      final manager = PluginManager();
      final core = _Plugin('core');
      final app = _Plugin('app');
      final observed = <String>[];
      final runner = PluginLifecycleRecoveryRunner(
        store: checkpoints,
        manager: manager,
        executor: _Executor((context) async {
          observed.add(context.plugin.metadata.id);
          await context.resumeStartup();
        }),
        clock: () => DateTime.utc(2026, 11, 14, 1),
      );

      final report = await runner.executeBatchWithJob(
        request: _request(core, app),
        jobStore: jobs,
        jobId: job.jobId,
      );

      expect(report.succeeded, isTrue);
      expect(report.orderedPluginIds, ['core', 'app']);
      expect(observed, ['core', 'app']);
      final persisted = (await jobs.read(job.jobId))!;
      expect(persisted.status, PluginRecoveryJobStatus.completed);
      expect(persisted.revision, 7);
      expect(persisted.steps.map((step) => step.status),
          everyElement(PluginRecoveryJobStepStatus.completed));
      expect(persisted.steps.map((step) => step.executionOperationId),
          ['job-core', 'job-app']);
    });

    test('rejects stale checkpoint snapshot before any plugin code', () async {
      final checkpoints = InMemoryPluginLifecycleCheckpointStore();
      await checkpoints.write(_checkpoint('core'));
      await checkpoints.write(_checkpoint('app', dependencies: ['core']));
      final jobs = InMemoryPluginLifecycleRecoveryJobStore();
      final job = _job();
      await jobs.insertIfAbsent(job);
      await checkpoints.write(PluginLifecycleCheckpoint(
        pluginId: 'core',
        operationId: 'changed-core',
        operation: PluginLifecycleOperation.startup,
        state: PluginLifecycleCheckpointState.starting,
        sequence: 3,
        attempt: 1,
        createdAt: DateTime.utc(2026, 11, 14),
        updatedAt: DateTime.utc(2026, 11, 14),
      ));
      var invoked = false;
      final runner = PluginLifecycleRecoveryRunner(
        store: checkpoints,
        manager: PluginManager(),
        executor: _Executor((context) async { invoked = true; }),
      );

      final report = await runner.executeBatchWithJob(
        request: _request(_Plugin('core'), _Plugin('app')),
        jobStore: jobs,
        jobId: job.jobId,
      );

      expect(report.succeeded, isFalse);
      expect(invoked, isFalse);
      expect((await jobs.read(job.jobId))!.status, PluginRecoveryJobStatus.planned);
    });

    test('records a failed step and leaves later steps pending', () async {
      final checkpoints = InMemoryPluginLifecycleCheckpointStore();
      await checkpoints.write(_checkpoint('core'));
      await checkpoints.write(_checkpoint('app', dependencies: ['core']));
      final jobs = InMemoryPluginLifecycleRecoveryJobStore();
      final job = _job();
      await jobs.insertIfAbsent(job);
      final runner = PluginLifecycleRecoveryRunner(
        store: checkpoints,
        manager: PluginManager(),
        executor: _Executor((context) async {
          throw StateError('host-side recovery validation failed');
        }),
      );

      final report = await runner.executeBatchWithJob(
        request: _request(_Plugin('core'), _Plugin('app')),
        jobStore: jobs,
        jobId: job.jobId,
      );

      expect(report.succeeded, isFalse);
      expect(report.failedPluginId, 'core');
      final persisted = (await jobs.read(job.jobId))!;
      expect(persisted.status, PluginRecoveryJobStatus.failed);
      expect(persisted.steps[0].status, PluginRecoveryJobStepStatus.failed);
      expect(persisted.steps[0].failureSummary,
          'Plugin recovery step failed; inspect lifecycle and external state');
      expect(persisted.steps[1].status, PluginRecoveryJobStepStatus.pending);
    });

    test('leaves a running claim when the post-side-effect journal write fails', () async {
      final checkpoints = InMemoryPluginLifecycleCheckpointStore();
      await checkpoints.write(_checkpoint('core'));
      await checkpoints.write(_checkpoint('app', dependencies: ['core']));
      final backingJobs = InMemoryPluginLifecycleRecoveryJobStore();
      final job = _job();
      await backingJobs.insertIfAbsent(job);
      final jobs = _FailCompletedStepStore(backingJobs);
      final manager = PluginManager();
      final core = _Plugin('core');
      final runner = PluginLifecycleRecoveryRunner(
        store: checkpoints,
        manager: manager,
        executor: _Executor((context) => context.resumeStartup()),
      );

      final report = await runner.executeBatchWithJob(
        request: _request(core, _Plugin('app')),
        jobStore: jobs,
        jobId: job.jobId,
      );

      expect(report.succeeded, isFalse);
      expect(core.activations, 1);
      final persisted = (await backingJobs.read(job.jobId))!;
      expect(persisted.status, PluginRecoveryJobStatus.running);
      expect(persisted.steps.first.status, PluginRecoveryJobStepStatus.running);
      expect((await checkpoints.read('core'))!.state,
          PluginLifecycleCheckpointState.active);
    });

    test('refuses to execute an already claimed or completed job', () async {
      final checkpoints = InMemoryPluginLifecycleCheckpointStore();
      await checkpoints.write(_checkpoint('core'));
      await checkpoints.write(_checkpoint('app', dependencies: ['core']));
      final jobs = InMemoryPluginLifecycleRecoveryJobStore();
      final job = _job();
      await jobs.insertIfAbsent(job);
      final running = job.next(
        status: PluginRecoveryJobStatus.running,
        at: DateTime.utc(2026, 11, 14, 1),
        steps: job.steps,
      );
      await jobs.compareAndSet(
        jobId: job.jobId,
        expectedRevision: job.revision,
        replacement: running,
      );
      var invoked = false;
      final runner = PluginLifecycleRecoveryRunner(
        store: checkpoints,
        manager: PluginManager(),
        executor: _Executor((context) async { invoked = true; }),
      );

      final report = await runner.executeBatchWithJob(
        request: _request(_Plugin('core'), _Plugin('app')),
        jobStore: jobs,
        jobId: job.jobId,
      );

      expect(report.succeeded, isFalse);
      expect(invoked, isFalse);
      expect((await jobs.read(job.jobId))!.revision, 2);
    });
  });
}
