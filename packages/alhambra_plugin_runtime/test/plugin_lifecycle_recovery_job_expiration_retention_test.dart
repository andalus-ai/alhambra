import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

PluginLifecycleRecoveryJob _job({
  DateTime? expiresAt,
  PluginRecoveryJobStatus status = PluginRecoveryJobStatus.planned,
}) {
  final now = DateTime.utc(2026, 11, 14);
  final planned = PluginLifecycleRecoveryJob.planned(
    jobId: 'job-expiry',
    idempotencyKey: 'idem-expiry',
    operationId: 'operation-expiry',
    action: PluginRecoveryJobAction.resumeStartup,
    orderedPluginIds: ['core', 'app'],
    at: now,
    expiresAt: expiresAt,
  );
  if (status == PluginRecoveryJobStatus.planned) return planned;
  return planned.next(
    status: status,
    at: now.add(const Duration(seconds: 1)),
    steps: planned.steps,
  );
}

final class _MemoryArchive implements PluginLifecycleRecoveryJobArchive {
  final Map<String, PluginLifecycleRecoveryJobArchiveRecord> records = {};

  @override
  Future<PluginLifecycleRecoveryJobArchiveRecord?> read(String jobId) async =>
      records[jobId];

  @override
  Future<bool> putIfAbsent(PluginLifecycleRecoveryJobArchiveRecord record) async {
    if (records.containsKey(record.job.jobId)) return false;
    records[record.job.jobId] = record;
    return true;
  }
}

void main() {
  group('PluginLifecycleRecoveryJobExpirationController', () {
    test('reports not due immediately before the expiry boundary', () async {
      final store = InMemoryPluginLifecycleRecoveryJobStore();
      final expiresAt = DateTime.utc(2026, 11, 15);
      final job = _job(expiresAt: expiresAt);
      await store.insertIfAbsent(job);
      final controller = PluginLifecycleRecoveryJobExpirationController(
        store: store,
      );

      final report = await controller.inspect(
        jobId: job.jobId,
        at: expiresAt.subtract(const Duration(microseconds: 1)),
      );

      expect(report.disposition, PluginRecoveryJobExpirationDisposition.notDue);
      expect(report.mayExpire, isFalse);
    });

    test('expires a planned job at the exact expiry boundary', () async {
      final store = InMemoryPluginLifecycleRecoveryJobStore();
      final expiresAt = DateTime.utc(2026, 11, 15);
      final job = _job(expiresAt: expiresAt);
      await store.insertIfAbsent(job);
      final controller = PluginLifecycleRecoveryJobExpirationController(
        store: store,
      );

      final report = await controller.inspect(jobId: job.jobId, at: expiresAt);
      expect(report.disposition, PluginRecoveryJobExpirationDisposition.eligible);

      final expired = await controller.expire(
        jobId: job.jobId,
        expectedRevision: job.revision,
        at: expiresAt,
      );

      expect(expired.status, PluginRecoveryJobStatus.expired);
      expect(expired.expiresAt, expiresAt);
      expect(expired.expiredAt, expiresAt);
      expect(expired.steps.map((step) => step.status),
          everyElement(PluginRecoveryJobStepStatus.skipped));
      expect((await store.read(job.jobId))!.status, PluginRecoveryJobStatus.expired);
    });

    test('does not expire jobs without expiry metadata', () async {
      final store = InMemoryPluginLifecycleRecoveryJobStore();
      final job = _job();
      await store.insertIfAbsent(job);
      final controller = PluginLifecycleRecoveryJobExpirationController(
        store: store,
      );

      final report = await controller.inspect(
        jobId: job.jobId,
        at: DateTime.utc(2027),
      );

      expect(report.disposition, PluginRecoveryJobExpirationDisposition.notConfigured);
      await expectLater(
        controller.expire(
          jobId: job.jobId,
          expectedRevision: job.revision,
          at: DateTime.utc(2027),
        ),
        throwsStateError,
      );
    });

    test('refuses to expire a running or cancellation-requested job', () async {
      final store = InMemoryPluginLifecycleRecoveryJobStore();
      final base = _job(expiresAt: DateTime.utc(2026, 11, 15));
      final running = base.next(
        status: PluginRecoveryJobStatus.running,
        at: DateTime.utc(2026, 11, 14, 1),
        steps: base.steps,
      );
      await store.insertIfAbsent(running);
      final controller = PluginLifecycleRecoveryJobExpirationController(
        store: store,
        clock: () => DateTime.utc(2026, 11, 16),
      );

      expect((await controller.inspect(jobId: running.jobId)).disposition,
          PluginRecoveryJobExpirationDisposition.notPlanned);
      await expectLater(
        controller.expire(
          jobId: running.jobId,
          expectedRevision: running.revision,
        ),
        throwsStateError,
      );
      expect((await store.read(running.jobId))!.status,
          PluginRecoveryJobStatus.running);
    });

    test('rejects stale revisions and repeated expiry', () async {
      final store = InMemoryPluginLifecycleRecoveryJobStore();
      final expiresAt = DateTime.utc(2026, 11, 15);
      final job = _job(expiresAt: expiresAt);
      await store.insertIfAbsent(job);
      final controller = PluginLifecycleRecoveryJobExpirationController(store: store);

      await expectLater(
        controller.expire(
          jobId: job.jobId,
          expectedRevision: job.revision + 1,
          at: expiresAt,
        ),
        throwsStateError,
      );
      final expired = await controller.expire(
        jobId: job.jobId,
        expectedRevision: job.revision,
        at: expiresAt,
      );
      await expectLater(
        controller.expire(
          jobId: job.jobId,
          expectedRevision: expired.revision,
          at: expiresAt.add(const Duration(days: 1)),
        ),
        throwsStateError,
      );
    });

    test('restart planner reports expired as terminal and requiring host action', () async {
      final jobs = InMemoryPluginLifecycleRecoveryJobStore();
      final checkpoints = InMemoryPluginLifecycleCheckpointStore();
      final base = _job(expiresAt: DateTime.utc(2026, 11, 15));
      final expired = base.next(
        status: PluginRecoveryJobStatus.expired,
        at: DateTime.utc(2026, 11, 15),
        expiredAt: DateTime.utc(2026, 11, 15),
        steps: base.steps,
      );
      await jobs.insertIfAbsent(expired);

      final report = await PluginLifecycleRecoveryJobPlanner(
        jobStore: jobs,
        checkpointStore: checkpoints,
      ).inspect(jobId: expired.jobId, activePluginIds: []);

      expect(report.disposition, PluginRecoveryJobDisposition.expired);
      expect(report.requiresHostAction, isTrue);
    });
  });

  group('PluginLifecycleRecoveryJobArchiver', () {
    test('archives terminal jobs idempotently without deleting operational copy', () async {
      final store = InMemoryPluginLifecycleRecoveryJobStore();
      final base = _job();
      final cancelled = base.next(
        status: PluginRecoveryJobStatus.cancelled,
        at: DateTime.utc(2026, 11, 14, 1),
        cancellationRequestedAt: DateTime.utc(2026, 11, 14, 1),
        steps: base.steps.map((step) => step.copyWith(
          status: PluginRecoveryJobStepStatus.skipped,
        )),
      );
      await store.insertIfAbsent(cancelled);
      final archive = _MemoryArchive();
      final archiver = PluginLifecycleRecoveryJobArchiver(
        jobStore: store,
        archive: archive,
        clock: () => DateTime.utc(2026, 11, 16),
      );

      final first = await archiver.archiveJob(
        jobId: cancelled.jobId,
        expectedRevision: cancelled.revision,
      );
      final second = await archiver.archiveJob(
        jobId: cancelled.jobId,
        expectedRevision: cancelled.revision,
      );

      expect(first.job.revision, cancelled.revision);
      expect(second.archivedAt, first.archivedAt);
      expect(archive.records, hasLength(1));
      expect((await store.read(cancelled.jobId))!.status,
          PluginRecoveryJobStatus.cancelled);
    });

    test('refuses to archive planned and running jobs', () async {
      final store = InMemoryPluginLifecycleRecoveryJobStore();
      final planned = _job();
      await store.insertIfAbsent(planned);
      final archive = _MemoryArchive();
      final archiver = PluginLifecycleRecoveryJobArchiver(
        jobStore: store,
        archive: archive,
      );

      await expectLater(
        archiver.archiveJob(
          jobId: planned.jobId,
          expectedRevision: planned.revision,
        ),
        throwsStateError,
      );
      expect(archive.records, isEmpty);
    });
  });
}
