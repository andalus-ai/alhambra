import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Archive implements PluginLifecycleRecoveryJobArchive {
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

final class _DigestProvider implements PluginLifecycleRecoveryJobDigestProvider {
  @override
  Future<String> digest({
    required String algorithm,
    required String canonicalPayload,
  }) async => '$algorithm-${canonicalPayload.length}';
}

PluginLifecycleRecoveryJob _job({String jobId = 'job-1'}) =>
    PluginLifecycleRecoveryJob(
      jobId: jobId,
      idempotencyKey: 'key-$jobId',
      operationId: 'operation-$jobId',
      action: PluginRecoveryJobAction.resumeStartup,
      orderedPluginIds: const ['plugin.a'],
      steps: [
        PluginRecoveryJobStep(
          pluginId: 'plugin.a',
          ordinal: 0,
          status: PluginRecoveryJobStepStatus.completed,
          completedAt: DateTime.utc(2026, 1, 1, 0, 1),
        ),
      ],
      status: PluginRecoveryJobStatus.completed,
      revision: 2,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1, 0, 1),
    );

PluginLifecycleRecoveryJobArchiveRecord _record({
  String jobId = 'job-1',
  int formatVersion = 2,
}) => PluginLifecycleRecoveryJobArchiveRecord(
  job: _job(jobId: jobId),
  archivedAt: DateTime.utc(2026, 1, 1, 0, 2),
  integrity: PluginLifecycleRecoveryJobArchiveIntegrity(
    formatVersion: formatVersion,
    algorithm: 'legacy',
    digest: 'legacy-digest',
  ),
);

PluginLifecycleRecoveryJobArchiveMigrationRegistry _registry() =>
    PluginLifecycleRecoveryJobArchiveMigrationRegistry([
      PluginLifecycleRecoveryJobArchiveFormatMigration(
        fromVersion: 2,
        toVersion: 1,
        migrate: (job) => job,
      ),
    ]);

void main() {
  group('PluginLifecycleRecoveryJobArchiveMigrationRegistry', () {
    test('finds a deterministic multi-step path', () {
      final registry = PluginLifecycleRecoveryJobArchiveMigrationRegistry([
        PluginLifecycleRecoveryJobArchiveFormatMigration(
          fromVersion: 3,
          toVersion: 2,
          migrate: (job) => job,
        ),
        PluginLifecycleRecoveryJobArchiveFormatMigration(
          fromVersion: 2,
          toVersion: 1,
          migrate: (job) => job,
        ),
      ]);

      final path = registry.findPath(fromVersion: 3, toVersion: 1);
      expect(path, isNotNull);
      expect(path!.steps.map((step) => step.fromVersion), [3, 2]);
      expect(path.steps.map((step) => step.toVersion), [2, 1]);
    });

    test('rejects ambiguous and cyclic migration definitions', () {
      expect(
        () => PluginLifecycleRecoveryJobArchiveMigrationRegistry([
          PluginLifecycleRecoveryJobArchiveFormatMigration(
            fromVersion: 2,
            toVersion: 1,
            migrate: (job) => job,
          ),
          PluginLifecycleRecoveryJobArchiveFormatMigration(
            fromVersion: 2,
            toVersion: 3,
            migrate: (job) => job,
          ),
        ]),
        throwsArgumentError,
      );

      final cyclic = PluginLifecycleRecoveryJobArchiveMigrationRegistry([
        PluginLifecycleRecoveryJobArchiveFormatMigration(
          fromVersion: 2,
          toVersion: 3,
          migrate: (job) => job,
        ),
        PluginLifecycleRecoveryJobArchiveFormatMigration(
          fromVersion: 3,
          toVersion: 2,
          migrate: (job) => job,
        ),
      ]);
      expect(cyclic.findPath(fromVersion: 2, toVersion: 1), isNull);
    });

    test('returns no path for unknown legacy versions', () {
      expect(_registry().findPath(fromVersion: 7, toVersion: 1), isNull);
    });
  });

  group('PluginLifecycleRecoveryJobArchiveMigrationPlanner', () {
    test('previews migration without changing source archive', () async {
      final source = _Archive()..records['job-1'] = _record();
      final plan = await PluginLifecycleRecoveryJobArchiveMigrationPlanner(
        sourceArchive: source,
        registry: _registry(),
      ).inspect(jobId: 'job-1');

      expect(plan.disposition, PluginRecoveryArchiveMigrationDisposition.ready);
      expect(plan.canMigrate, isTrue);
      expect(plan.sourceFormatVersion, 2);
      expect(plan.targetFormatVersion, 1);
      expect(source.records['job-1']!.integrity.formatVersion, 2);
    });

    test('reports missing records and unsupported migration paths', () async {
      final source = _Archive();
      final planner = PluginLifecycleRecoveryJobArchiveMigrationPlanner(
        sourceArchive: source,
        registry: _registry(),
      );

      expect(
        (await planner.inspect(jobId: 'absent')).disposition,
        PluginRecoveryArchiveMigrationDisposition.missing,
      );

      source.records['job-1'] = _record(formatVersion: 8);
      expect(
        (await planner.inspect(jobId: 'job-1')).disposition,
        PluginRecoveryArchiveMigrationDisposition.noMigrationPath,
      );
    });

    test('identifies records already in the target format', () async {
      final source = _Archive()..records['job-1'] = _record(formatVersion: 1);
      final plan = await PluginLifecycleRecoveryJobArchiveMigrationPlanner(
        sourceArchive: source,
        registry: _registry(),
      ).inspect(jobId: 'job-1');

      expect(plan.disposition, PluginRecoveryArchiveMigrationDisposition.alreadyCurrent);
      expect(plan.canMigrate, isFalse);
    });
  });

  group('PluginLifecycleRecoveryJobArchiveMigrationExecutor', () {
    test('verifies source and imports a re-digested current-format copy', () async {
      final source = _Archive()..records['job-1'] = _record();
      final destination = _Archive();
      final plan = await PluginLifecycleRecoveryJobArchiveMigrationPlanner(
        sourceArchive: source,
        registry: _registry(),
      ).inspect(jobId: 'job-1');
      final executor = PluginLifecycleRecoveryJobArchiveMigrationExecutor(
        sourceArchive: source,
        destinationArchive: destination,
        digestProvider: _DigestProvider(),
        digestAlgorithm: 'test-v1',
        verifySource: (_) async => true,
      );

      final result = await executor.migrate(plan);
      expect(result, PluginRecoveryArchiveMigrationDisposition.imported);
      expect(destination.records['job-1']!.integrity.formatVersion, 1);
      expect(destination.records['job-1']!.integrity.algorithm, 'test-v1');
      expect(destination.records['job-1']!.integrity.digest, isNotEmpty);
      expect(source.records['job-1']!.integrity.formatVersion, 2);
    });

    test('is idempotent when destination already has the same migrated record', () async {
      final source = _Archive()..records['job-1'] = _record();
      final destination = _Archive();
      final plan = await PluginLifecycleRecoveryJobArchiveMigrationPlanner(
        sourceArchive: source,
        registry: _registry(),
      ).inspect(jobId: 'job-1');
      final executor = PluginLifecycleRecoveryJobArchiveMigrationExecutor(
        sourceArchive: source,
        destinationArchive: destination,
        digestProvider: _DigestProvider(),
        digestAlgorithm: 'test-v1',
        verifySource: (_) async => true,
      );

      expect(await executor.migrate(plan), PluginRecoveryArchiveMigrationDisposition.imported);
      expect(await executor.migrate(plan), PluginRecoveryArchiveMigrationDisposition.alreadyPresent);
    });

    test('fails closed when source integrity verification fails', () async {
      final source = _Archive()..records['job-1'] = _record();
      final destination = _Archive();
      final plan = await PluginLifecycleRecoveryJobArchiveMigrationPlanner(
        sourceArchive: source,
        registry: _registry(),
      ).inspect(jobId: 'job-1');
      final executor = PluginLifecycleRecoveryJobArchiveMigrationExecutor(
        sourceArchive: source,
        destinationArchive: destination,
        digestProvider: _DigestProvider(),
        digestAlgorithm: 'test-v1',
        verifySource: (_) async => false,
      );

      await expectLater(executor.migrate(plan), throwsStateError);
      expect(destination.records, isEmpty);
    });

    test('rejects stale plans and conflicting destination records', () async {
      final source = _Archive()..records['job-1'] = _record();
      final destination = _Archive();
      final planner = PluginLifecycleRecoveryJobArchiveMigrationPlanner(
        sourceArchive: source,
        registry: _registry(),
      );
      final stalePlan = await planner.inspect(jobId: 'job-1');
      source.records['job-1'] = _record(formatVersion: 3);
      final staleExecutor = PluginLifecycleRecoveryJobArchiveMigrationExecutor(
        sourceArchive: source,
        destinationArchive: destination,
        digestProvider: _DigestProvider(),
        digestAlgorithm: 'test-v1',
        verifySource: (_) async => true,
      );
      await expectLater(staleExecutor.migrate(stalePlan), throwsStateError);

      source.records['job-1'] = _record();
      final freshPlan = await planner.inspect(jobId: 'job-1');
      destination.records['job-1'] = _record(formatVersion: 1);
      final conflictExecutor = PluginLifecycleRecoveryJobArchiveMigrationExecutor(
        sourceArchive: source,
        destinationArchive: destination,
        digestProvider: _DigestProvider(),
        digestAlgorithm: 'test-v1',
        verifySource: (_) async => true,
      );
      await expectLater(conflictExecutor.migrate(freshPlan), throwsStateError);
    });

    test('rejects migrations that alter recovery-job identity', () async {
      final source = _Archive()..records['job-1'] = _record();
      final destination = _Archive();
      final badRegistry = PluginLifecycleRecoveryJobArchiveMigrationRegistry([
        PluginLifecycleRecoveryJobArchiveFormatMigration(
          fromVersion: 2,
          toVersion: 1,
          migrate: (job) => _job(jobId: 'other-job'),
        ),
      ]);
      final plan = await PluginLifecycleRecoveryJobArchiveMigrationPlanner(
        sourceArchive: source,
        registry: badRegistry,
      ).inspect(jobId: 'job-1');
      final executor = PluginLifecycleRecoveryJobArchiveMigrationExecutor(
        sourceArchive: source,
        destinationArchive: destination,
        digestProvider: _DigestProvider(),
        digestAlgorithm: 'test-v1',
        verifySource: (_) async => true,
      );

      await expectLater(executor.migrate(plan), throwsStateError);
      expect(destination.records, isEmpty);
    });
  });
}
