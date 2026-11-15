import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:alhambra_plugin_test/alhambra_plugin_test.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Archive implements PluginLifecycleRecoveryJobArchivePurgeStore {
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

PluginLifecycleRecoveryJobArchiveRecord _fixture(String jobId, int variant) {
  final createdAt = DateTime.utc(2026, 1, 1);
  final completedAt = DateTime.utc(2026, 1, 1, 0, 1);
  final job = PluginLifecycleRecoveryJob(
    jobId: jobId,
    idempotencyKey: 'key-$jobId',
    operationId: 'operation-$jobId',
    action: PluginRecoveryJobAction.resumeStartup,
    orderedPluginIds: const ['example.plugin'],
    steps: [
      PluginRecoveryJobStep(
        pluginId: 'example.plugin',
        ordinal: 0,
        status: PluginRecoveryJobStepStatus.completed,
        completedAt: completedAt,
      ),
    ],
    status: PluginRecoveryJobStatus.completed,
    revision: 2,
    createdAt: createdAt,
    updatedAt: completedAt,
    correlationId: 'variant-$variant',
  );
  return PluginLifecycleRecoveryJobArchiveRecord(
    job: job,
    archivedAt: DateTime.utc(2026, 1, 1, 0, 2),
    integrity: PluginLifecycleRecoveryJobArchiveIntegrity(
      formatVersion: 1,
      algorithm: 'test-only',
      digest: 'digest-$variant',
    ),
  );
}

void main() {
  group('PluginRecoveryArchiveConformanceSuite', () {
    test('checks insert, read, duplicate, conflict, and digest-guarded purge', () async {
      final archive = _Archive();
      final report = await const PluginRecoveryArchiveConformanceSuite().verify(
        archive: archive,
        runId: 'suite-one',
        fixtureBuilder: _fixture,
      );

      expect(report.isConformant, isTrue, reason: report.checks
          .where((check) => check.status == PluginRecoveryArchiveConformanceStatus.failed)
          .map((check) => '${check.name}: ${check.detail}').join('\n'));
      expect(report.passedCount, 6);
      expect(report.failedCount, 0);
      expect(report.skippedCount, 0);
      expect(archive.records.keys, contains('archive-conformance-suite-one-concurrent'));
      expect(archive.records.keys, isNot(contains('archive-conformance-suite-one-purge')));
    });

    test('skips optional purge checks for a basic archive adapter', () async {
      final archive = _BasicArchive();
      final report = await const PluginRecoveryArchiveConformanceSuite().verify(
        archive: archive,
        runId: 'suite-two',
        fixtureBuilder: _fixture,
      );

      expect(report.isConformant, isTrue);
      expect(report.skippedCount, 1);
    });

    test('rejects invalid run identifiers and writer counts', () async {
      final suite = const PluginRecoveryArchiveConformanceSuite();
      expect(
        () => suite.verify(
          archive: _Archive(),
          runId: 'not safe',
          fixtureBuilder: _fixture,
        ),
        throwsArgumentError,
      );
      expect(
        () => suite.verify(
          archive: _Archive(),
          runId: 'valid',
          concurrentWriters: 1,
          fixtureBuilder: _fixture,
        ),
        throwsArgumentError,
      );
    });
  });
}

final class _BasicArchive implements PluginLifecycleRecoveryJobArchive {
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
