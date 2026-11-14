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

final class _MemoryArchive implements PluginLifecycleRecoveryJobArchivePurgeStore {
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

  @override
  Future<bool> deleteIfDigestMatches({
    required String jobId,
    required String expectedDigest,
  }) async {
    final record = records[jobId];
    if (record == null || record.integrity.digest != expectedDigest) return false;
    records.remove(jobId);
    return true;
  }
}

final class _TestDigestProvider
    implements PluginLifecycleRecoveryJobDigestProvider {
  @override
  Future<String> digest({
    required String algorithm,
    required String canonicalPayload,
  }) async {
    if (algorithm != 'test-fnv32') throw ArgumentError('Unsupported test algorithm.');
    var hash = 0x811c9dc5;
    for (final unit in canonicalPayload.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}



final class _TestPurgeAuditSink implements PluginRecoveryArchivePurgeAuditSink {
  final void Function(PluginRecoveryArchivePurgeAuditEvent) onRecord;
  _TestPurgeAuditSink(this.onRecord);

  @override
  Future<void> record(PluginRecoveryArchivePurgeAuditEvent event) async {
    onRecord(event);
  }
}

final class _FailingPurgeAuditSink implements PluginRecoveryArchivePurgeAuditSink {
  @override
  Future<void> record(PluginRecoveryArchivePurgeAuditEvent event) async {
    throw StateError('audit unavailable');
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

    test('refuses expiry when a planned job contains a started step', () async {
      final store = InMemoryPluginLifecycleRecoveryJobStore();
      final now = DateTime.utc(2026, 11, 14);
      final job = PluginLifecycleRecoveryJob.planned(
        jobId: 'job-started-step',
        idempotencyKey: 'idem-started-step',
        operationId: 'operation-started-step',
        action: PluginRecoveryJobAction.resumeStartup,
        orderedPluginIds: ['core', 'app'],
        at: now,
        expiresAt: now.add(const Duration(minutes: 1)),
        steps: [
          PluginRecoveryJobStep(
            pluginId: 'core',
            ordinal: 0,
            status: PluginRecoveryJobStepStatus.running,
            startedAt: now,
          ),
          PluginRecoveryJobStep(pluginId: 'app', ordinal: 1),
        ],
      );
      await store.insertIfAbsent(job);
      final controller = PluginLifecycleRecoveryJobExpirationController(
        store: store,
        clock: () => now.add(const Duration(days: 1)),
      );

      expect((await controller.inspect(jobId: job.jobId)).disposition,
          PluginRecoveryJobExpirationDisposition.hasStarted);
      await expectLater(
        controller.expire(
          jobId: job.jobId,
          expectedRevision: job.revision,
        ),
        throwsStateError,
      );
      expect((await store.read(job.jobId))!.status,
          PluginRecoveryJobStatus.planned);
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
        digestProvider: _TestDigestProvider(),
        digestAlgorithm: 'test-fnv32',
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
        digestProvider: _TestDigestProvider(),
        digestAlgorithm: 'test-fnv32',
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

  group('PluginLifecycleRecoveryJobArchiveVerifier and Restorer', () {
    test('verifies and restores an archived terminal snapshot without execution', () async {
      final operational = InMemoryPluginLifecycleRecoveryJobStore();
      final base = _job();
      final cancelled = base.next(
        status: PluginRecoveryJobStatus.cancelled,
        at: DateTime.utc(2026, 11, 14, 1),
        cancellationRequestedAt: DateTime.utc(2026, 11, 14, 1),
        steps: base.steps.map((step) => step.copyWith(
          status: PluginRecoveryJobStepStatus.skipped,
        )),
      );
      await operational.insertIfAbsent(cancelled);
      final archive = _MemoryArchive();
      final digests = _TestDigestProvider();
      final archiver = PluginLifecycleRecoveryJobArchiver(
        jobStore: operational,
        archive: archive,
        digestProvider: digests,
        digestAlgorithm: 'test-fnv32',
        clock: () => DateTime.utc(2026, 11, 16),
      );
      await archiver.archiveJob(
        jobId: cancelled.jobId,
        expectedRevision: cancelled.revision,
      );

      final restoredStore = InMemoryPluginLifecycleRecoveryJobStore();
      final verifier = PluginLifecycleRecoveryJobArchiveVerifier(
        archive: archive,
        digestProvider: digests,
      );
      expect((await verifier.verify(cancelled.jobId)).isValid, isTrue);

      final restorer = PluginLifecycleRecoveryJobArchiveRestorer(
        archive: archive,
        jobStore: restoredStore,
        verifier: verifier,
      );
      final result = await restorer.restore(jobId: cancelled.jobId);
      expect(result.disposition, PluginLifecycleRecoveryJobRestoreDisposition.restored);
      expect(result.job.status, PluginRecoveryJobStatus.cancelled);
      expect((await restoredStore.read(cancelled.jobId))!.revision, cancelled.revision);
      expect((await restorer.restore(jobId: cancelled.jobId)).disposition,
          PluginLifecycleRecoveryJobRestoreDisposition.alreadyPresent);
    });

    test('detects a modified archived snapshot before restore', () async {
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
      final digests = _TestDigestProvider();
      await PluginLifecycleRecoveryJobArchiver(
        jobStore: store,
        archive: archive,
        digestProvider: digests,
        digestAlgorithm: 'test-fnv32',
      ).archiveJob(jobId: cancelled.jobId, expectedRevision: cancelled.revision);

      final record = archive.records[cancelled.jobId]!;
      final modified = record.job.next(
        status: PluginRecoveryJobStatus.cancelled,
        at: record.job.updatedAt.add(const Duration(seconds: 1)),
        cancellationRequestedAt: record.job.cancellationRequestedAt,
        steps: record.job.steps,
      );
      archive.records[cancelled.jobId] = PluginLifecycleRecoveryJobArchiveRecord(
        job: modified,
        archivedAt: record.archivedAt,
        integrity: record.integrity,
      );

      final verifier = PluginLifecycleRecoveryJobArchiveVerifier(
        archive: archive,
        digestProvider: digests,
      );
      expect((await verifier.verify(cancelled.jobId)).disposition,
          PluginRecoveryArchiveVerificationDisposition.invalidDigest);
      final target = InMemoryPluginLifecycleRecoveryJobStore();
      await expectLater(
        PluginLifecycleRecoveryJobArchiveRestorer(
          archive: archive,
          jobStore: target,
          verifier: verifier,
        ).restore(jobId: cancelled.jobId),
        throwsStateError,
      );
      expect(await target.read(cancelled.jobId), isNull);
    });
  });

  group('PluginLifecycleRecoveryJobRetentionInspector and Purger', () {
    test('blocks purge for active retention, legal hold, and audit preservation', () async {
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
      final digests = _TestDigestProvider();
      await PluginLifecycleRecoveryJobArchiver(
        jobStore: store,
        archive: archive,
        digestProvider: digests,
        digestAlgorithm: 'test-fnv32',
      ).archiveJob(jobId: cancelled.jobId, expectedRevision: cancelled.revision);

      final inspector = PluginLifecycleRecoveryJobRetentionInspector(
        archive: archive,
      );
      final active = await inspector.inspect(
        jobId: cancelled.jobId,
        policy: PluginLifecycleRecoveryJobRetentionPolicy(
          retainUntil: DateTime.utc(2026, 12, 1),
        ),
        at: DateTime.utc(2026, 11, 30),
      );
      final held = await inspector.inspect(
        jobId: cancelled.jobId,
        policy: PluginLifecycleRecoveryJobRetentionPolicy(
          retainUntil: DateTime.utc(2026, 11, 1),
          legalHold: true,
        ),
        at: DateTime.utc(2027),
      );
      final auditProtected = await inspector.inspect(
        jobId: cancelled.jobId,
        policy: PluginLifecycleRecoveryJobRetentionPolicy(
          retainUntil: DateTime.utc(2026, 11, 1),
          auditPreservationRequired: true,
        ),
        at: DateTime.utc(2027),
      );

      expect(active.disposition,
          PluginRecoveryArchiveRetentionDisposition.retentionPeriodActive);
      expect(held.disposition, PluginRecoveryArchiveRetentionDisposition.legalHold);
      expect(auditProtected.disposition,
          PluginRecoveryArchiveRetentionDisposition.auditPreservationRequired);
    });

    test('requires durable purge audit and explicit authorization before deleting archive', () async {
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
      final digests = _TestDigestProvider();
      final record = await PluginLifecycleRecoveryJobArchiver(
        jobStore: store,
        archive: archive,
        digestProvider: digests,
        digestAlgorithm: 'test-fnv32',
      ).archiveJob(jobId: cancelled.jobId, expectedRevision: cancelled.revision);
      final inspector = PluginLifecycleRecoveryJobRetentionInspector(archive: archive);
      var auditWritten = false;
      final purger = PluginLifecycleRecoveryJobArchivePurger(
        archive: archive,
        inspector: inspector,
        auditSink: _TestPurgeAuditSink((_) => auditWritten = true),
        clock: () => DateTime.utc(2027),
      );

      await purger.purge(
        jobId: cancelled.jobId,
        policy: PluginLifecycleRecoveryJobRetentionPolicy(
          retainUntil: DateTime.utc(2026, 12, 1),
        ),
        authorization: PluginRecoveryArchivePurgeAuthorization(
          authorizedBy: 'operator',
          approvalReference: 'change-123',
          approvedAt: DateTime.utc(2026, 12, 2),
        ),
        expectedDigest: record.integrity.digest,
      );

      expect(auditWritten, isTrue);
      expect(archive.records, isEmpty);
      expect((await store.read(cancelled.jobId))!.status,
          PluginRecoveryJobStatus.cancelled);
    });

    test('does not purge if audit persistence fails', () async {
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
      final digests = _TestDigestProvider();
      final record = await PluginLifecycleRecoveryJobArchiver(
        jobStore: store,
        archive: archive,
        digestProvider: digests,
        digestAlgorithm: 'test-fnv32',
      ).archiveJob(jobId: cancelled.jobId, expectedRevision: cancelled.revision);
      final purger = PluginLifecycleRecoveryJobArchivePurger(
        archive: archive,
        inspector: PluginLifecycleRecoveryJobRetentionInspector(archive: archive),
        auditSink: _FailingPurgeAuditSink(),
      );

      await expectLater(
        purger.purge(
          jobId: cancelled.jobId,
          policy: PluginLifecycleRecoveryJobRetentionPolicy(
            retainUntil: DateTime.utc(2026, 12, 1),
          ),
          authorization: PluginRecoveryArchivePurgeAuthorization(
            authorizedBy: 'operator',
            approvalReference: 'change-456',
            approvedAt: DateTime.utc(2026, 12, 2),
          ),
          expectedDigest: record.integrity.digest,
          at: DateTime.utc(2027),
        ),
        throwsStateError,
      );
      expect(archive.records, hasLength(1));
    });
  });
}
