import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Archive implements PluginLifecycleRecoveryJobArchive {
  final Map<String, PluginLifecycleRecoveryJobArchiveRecord> records = {};
  @override
  Future<PluginLifecycleRecoveryJobArchiveRecord?> read(String jobId) async => records[jobId];
  @override
  Future<bool> putIfAbsent(PluginLifecycleRecoveryJobArchiveRecord record) async {
    if (records.containsKey(record.job.jobId)) return false;
    records[record.job.jobId] = record;
    return true;
  }
}

final class _Digest implements PluginLifecycleRecoveryJobDigestProvider {
  @override
  Future<String> digest({required String algorithm, required String canonicalPayload}) async =>
      '$algorithm-${canonicalPayload.hashCode}-${canonicalPayload.length}';
}

PluginLifecycleRecoveryJob _job(String id) => PluginLifecycleRecoveryJob(
  jobId: id,
  idempotencyKey: 'key-$id',
  operationId: 'operation-$id',
  action: PluginRecoveryJobAction.resumeStartup,
  orderedPluginIds: const ['plugin.one'],
  steps: [PluginRecoveryJobStep(
    pluginId: 'plugin.one', ordinal: 0,
    status: PluginRecoveryJobStepStatus.completed,
    completedAt: DateTime.utc(2026, 11, 1, 0, 1),
  )],
  status: PluginRecoveryJobStatus.completed,
  revision: 2,
  createdAt: DateTime.utc(2026, 11, 1),
  updatedAt: DateTime.utc(2026, 11, 1, 0, 1),
);

Future<PluginLifecycleRecoveryJobArchiveRecord> _record(String id, _Digest digest) async {
  final job = _job(id);
  final archivedAt = DateTime.utc(2026, 11, 1, 0, 2);
  const codec = PluginLifecycleRecoveryJobSnapshotCodec();
  final value = await digest.digest(
    algorithm: 'test-v1',
    canonicalPayload: codec.encode(job, archivedAt: archivedAt),
  );
  return PluginLifecycleRecoveryJobArchiveRecord(
    job: job,
    archivedAt: archivedAt,
    integrity: PluginLifecycleRecoveryJobArchiveIntegrity(
      formatVersion: PluginLifecycleRecoveryJobSnapshotCodec.formatVersion,
      algorithm: 'test-v1',
      digest: value,
    ),
  );
}

void main() {
  group('PluginRecoveryArchivePackageCodec', () {
    test('round-trips manifest, records, and job fields', () async {
      final digest = _Digest();
      final record = await _record('job-a', digest);
      final package = await PluginRecoveryArchivePackageExporter(
        digestProvider: digest, digestAlgorithm: 'package-test',
      ).create(
        packageId: 'bundle-1', producer: 'test-host',
        createdAt: DateTime.utc(2026, 11, 2), records: [record],
      );
      const codec = PluginRecoveryArchivePackageCodec();
      final decoded = codec.decode(codec.encode(package));
      expect(decoded.manifest.packageId, 'bundle-1');
      expect(decoded.manifest.recordCount, 1);
      expect(decoded.records.single.job.jobId, 'job-a');
      expect(decoded.records.single.job.steps.single.status, PluginRecoveryJobStepStatus.completed);
      expect(decoded.digest, package.digest);
      expect(codec.encode(decoded), codec.encode(package));
    });

    test('rejects malformed enum values and duplicate record identities', () async {
      final digest = _Digest();
      final record = await _record('job-a', digest);
      final package = await PluginRecoveryArchivePackageExporter(
        digestProvider: digest, digestAlgorithm: 'package-test',
      ).create(
        packageId: 'bundle-1', producer: 'test-host',
        createdAt: DateTime.utc(2026, 11, 2), records: [record],
      );
      const codec = PluginRecoveryArchivePackageCodec();
      final json = codec.encode(package).replaceFirst('"action":"resumeStartup"', '"action":"unknown"');
      expect(() => codec.decode(json), throwsFormatException);
      expect(() => PluginRecoveryArchivePackage(
        manifest: package.manifest, records: [record, record],
        digestAlgorithm: package.digestAlgorithm, digest: package.digest,
      ), throwsArgumentError);
    });
  });

  group('PluginRecoveryArchivePackageImporter', () {
    test('inspects, verifies, and imports a package without executing jobs', () async {
      final digest = _Digest();
      final records = [await _record('job-a', digest), await _record('job-b', digest)];
      final package = await PluginRecoveryArchivePackageExporter(
        digestProvider: digest, digestAlgorithm: 'package-test',
      ).create(
        packageId: 'bundle-1', producer: 'test-host',
        createdAt: DateTime.utc(2026, 11, 2), records: records,
      );
      final destination = _Archive();
      final importer = PluginRecoveryArchivePackageImporter(
        destinationArchive: destination, digestProvider: digest,
      );
      final plan = await importer.inspect(package);
      expect(plan.disposition, PluginRecoveryArchivePackageImportDisposition.ready);
      expect(plan.validJobIds, ['job-a', 'job-b']);
      final report = await importer.importPackage(plan);
      expect(report.disposition, PluginRecoveryArchivePackageImportDisposition.imported);
      expect(report.importedJobIds, ['job-a', 'job-b']);
      expect(destination.records.keys, containsAll(['job-a', 'job-b']));
      expect(destination.records['job-a']!.job.status, PluginRecoveryJobStatus.completed);
    });

    test('detects tampered package and invalid per-record digest', () async {
      final digest = _Digest();
      final record = await _record('job-a', digest);
      final package = await PluginRecoveryArchivePackageExporter(
        digestProvider: digest, digestAlgorithm: 'package-test',
      ).create(
        packageId: 'bundle-1', producer: 'test-host',
        createdAt: DateTime.utc(2026, 11, 2), records: [record],
      );
      final importer = PluginRecoveryArchivePackageImporter(
        destinationArchive: _Archive(), digestProvider: digest,
      );
      final badEnvelope = PluginRecoveryArchivePackage(
        manifest: package.manifest, records: package.records,
        digestAlgorithm: package.digestAlgorithm, digest: 'tampered',
      );
      expect((await importer.inspect(badEnvelope)).disposition,
          PluginRecoveryArchivePackageImportDisposition.invalidPackageDigest);

      final badRecord = PluginLifecycleRecoveryJobArchiveRecord(
        job: record.job, archivedAt: record.archivedAt,
        integrity: PluginLifecycleRecoveryJobArchiveIntegrity(
          formatVersion: record.integrity.formatVersion,
          algorithm: record.integrity.algorithm, digest: 'tampered',
        ),
      );
      final manifest = PluginRecoveryArchivePackageManifest(
        formatVersion: PluginRecoveryArchivePackageManifest.currentFormatVersion,
        packageId: 'bundle-2',
        producer: 'test-host',
        createdAt: DateTime.utc(2026, 11, 2),
        recordCount: 1,
      );
      const packageCodec = PluginRecoveryArchivePackageCodec();
      final packagePayload = packageCodec.encodePayload(
        manifest: manifest,
        records: [badRecord],
      );
      final invalidPackage = PluginRecoveryArchivePackage(
        manifest: manifest,
        records: [badRecord],
        digestAlgorithm: 'package-test',
        digest: await digest.digest(
          algorithm: 'package-test',
          canonicalPayload: packagePayload,
        ),
      );
      expect((await importer.inspect(invalidPackage)).disposition,
          PluginRecoveryArchivePackageImportDisposition.invalidRecord);
    });

    test('reports destination conflicts and idempotent existing records', () async {
      final digest = _Digest();
      final record = await _record('job-a', digest);
      final package = await PluginRecoveryArchivePackageExporter(
        digestProvider: digest, digestAlgorithm: 'package-test',
      ).create(
        packageId: 'bundle-1', producer: 'test-host',
        createdAt: DateTime.utc(2026, 11, 2), records: [record],
      );
      final destination = _Archive()..records['job-a'] = record;
      final importer = PluginRecoveryArchivePackageImporter(
        destinationArchive: destination, digestProvider: digest,
      );
      final existingPlan = await importer.inspect(package);
      expect(existingPlan.disposition, PluginRecoveryArchivePackageImportDisposition.alreadyPresent);
      expect((await importer.importPackage(existingPlan)).disposition,
          PluginRecoveryArchivePackageImportDisposition.alreadyPresent);

      final failed = record.job.next(
        status: PluginRecoveryJobStatus.failed,
        at: DateTime.utc(2026, 11, 1, 0, 3),
        failureSummary: 'sanitized failure',
        steps: [PluginRecoveryJobStep(
          pluginId: 'plugin.one', ordinal: 0,
          status: PluginRecoveryJobStepStatus.failed,
          failureSummary: 'sanitized failure',
        )],
      );
      final conflictRecord = PluginLifecycleRecoveryJobArchiveRecord(
        job: failed, archivedAt: record.archivedAt,
        integrity: PluginLifecycleRecoveryJobArchiveIntegrity(
          formatVersion: PluginLifecycleRecoveryJobSnapshotCodec.formatVersion,
          algorithm: 'test-v1',
          digest: await digest.digest(
            algorithm: 'test-v1',
            canonicalPayload: const PluginLifecycleRecoveryJobSnapshotCodec()
                .encode(failed, archivedAt: record.archivedAt),
          ),
        ),
      );
      final conflictPackage = await PluginRecoveryArchivePackageExporter(
        digestProvider: digest, digestAlgorithm: 'package-test',
      ).create(
        packageId: 'bundle-2', producer: 'test-host',
        createdAt: DateTime.utc(2026, 11, 2), records: [conflictRecord],
      );
      expect((await importer.inspect(conflictPackage)).disposition,
          PluginRecoveryArchivePackageImportDisposition.destinationConflict);
    });

    test('re-inspects before import and safely accepts identical concurrent insertion', () async {
      final digest = _Digest();
      final record = await _record('job-a', digest);
      final package = await PluginRecoveryArchivePackageExporter(
        digestProvider: digest, digestAlgorithm: 'package-test',
      ).create(
        packageId: 'bundle-1', producer: 'test-host',
        createdAt: DateTime.utc(2026, 11, 2), records: [record],
      );
      final destination = _Archive();
      final importer = PluginRecoveryArchivePackageImporter(
        destinationArchive: destination, digestProvider: digest,
      );
      final plan = await importer.inspect(package);
      destination.records['job-a'] = record;
      final report = await importer.importPackage(plan);
      expect(report.disposition, PluginRecoveryArchivePackageImportDisposition.alreadyPresent);
    });
  });
}
