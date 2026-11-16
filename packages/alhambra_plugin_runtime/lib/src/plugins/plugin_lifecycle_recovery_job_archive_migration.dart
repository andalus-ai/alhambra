import 'plugin_lifecycle_recovery_job.dart';
import 'plugin_lifecycle_recovery_job_archive.dart';
import 'plugin_lifecycle_recovery_job_archive_integrity.dart';
import 'plugin_lifecycle_recovery_job_archive_integrity_metadata.dart';

typedef PluginRecoveryArchiveJobMigration =
    PluginLifecycleRecoveryJob Function(PluginLifecycleRecoveryJob job);

typedef PluginRecoveryArchiveSourceVerifier =
    Future<bool> Function(PluginLifecycleRecoveryJobArchiveRecord record);

/// One explicit, deterministic archive-format migration step.
///
/// Migrations transform only the persisted recovery-job value. They must not
/// execute plugin hooks, access external resources, or change job identity.
final class PluginLifecycleRecoveryJobArchiveFormatMigration {
  final int fromVersion;
  final int toVersion;
  final PluginRecoveryArchiveJobMigration migrate;

  const PluginLifecycleRecoveryJobArchiveFormatMigration({
    required this.fromVersion,
    required this.toVersion,
    required this.migrate,
  }) {
    if (fromVersion < 1) throw ArgumentError.value(fromVersion, 'fromVersion');
    if (toVersion < 1) throw ArgumentError.value(toVersion, 'toVersion');
    if (fromVersion == toVersion) {
      throw ArgumentError('A migration must change the archive format version.');
    }
  }
}

/// Immutable migration path selected by the registry.
final class PluginRecoveryArchiveFormatMigrationPath {
  final int fromVersion;
  final int toVersion;
  final List<PluginLifecycleRecoveryJobArchiveFormatMigration> steps;

  PluginRecoveryArchiveFormatMigrationPath({
    required this.fromVersion,
    required this.toVersion,
    required Iterable<PluginLifecycleRecoveryJobArchiveFormatMigration> steps,
  }) : steps = List.unmodifiable(steps);

  bool get isEmpty => steps.isEmpty;
}

/// Explicit registry; it never guesses how an unknown archive format should
/// be interpreted. At most one outgoing migration may exist for each version.
final class PluginLifecycleRecoveryJobArchiveMigrationRegistry {
  final Map<int, PluginLifecycleRecoveryJobArchiveFormatMigration> _bySource;

  PluginLifecycleRecoveryJobArchiveMigrationRegistry(
    Iterable<PluginLifecycleRecoveryJobArchiveFormatMigration> migrations,
  ) : _bySource = _index(migrations);

  static Map<int, PluginLifecycleRecoveryJobArchiveFormatMigration> _index(
    Iterable<PluginLifecycleRecoveryJobArchiveFormatMigration> migrations,
  ) {
    final result = <int, PluginLifecycleRecoveryJobArchiveFormatMigration>{};
    for (final migration in migrations) {
      if (result.containsKey(migration.fromVersion)) {
        throw ArgumentError('Ambiguous archive migration from version ${migration.fromVersion}.');
      }
      result[migration.fromVersion] = migration;
    }
    return Map.unmodifiable(result);
  }

  PluginRecoveryArchiveFormatMigrationPath? findPath({
    required int fromVersion,
    required int toVersion,
  }) {
    if (fromVersion < 1 || toVersion < 1) {
      throw ArgumentError('Archive format versions must be positive.');
    }
    if (fromVersion == toVersion) {
      return PluginRecoveryArchiveFormatMigrationPath(
        fromVersion: fromVersion,
        toVersion: toVersion,
        steps: const [],
      );
    }
    final steps = <PluginLifecycleRecoveryJobArchiveFormatMigration>[];
    final visited = <int>{fromVersion};
    var current = fromVersion;
    while (current != toVersion) {
      final migration = _bySource[current];
      if (migration == null || !visited.add(migration.toVersion)) return null;
      steps.add(migration);
      current = migration.toVersion;
      if (steps.length > _bySource.length) return null;
    }
    return PluginRecoveryArchiveFormatMigrationPath(
      fromVersion: fromVersion,
      toVersion: toVersion,
      steps: steps,
    );
  }
}

enum PluginRecoveryArchiveMigrationDisposition {
  ready,
  alreadyCurrent,
  missing,
  unsupportedJobSchema,
  noMigrationPath,
  sourceChanged,
  imported,
  alreadyPresent,
}

/// Read-only preview. It contains the exact source snapshot observed during
/// inspection so execution can reject stale approval.
final class PluginRecoveryArchiveMigrationPlan {
  final String jobId;
  final PluginRecoveryArchiveMigrationDisposition disposition;
  final int? sourceFormatVersion;
  final int targetFormatVersion;
  final String? sourceDigest;
  final DateTime? archivedAt;
  final PluginLifecycleRecoveryJobArchiveRecord? sourceRecord;
  final PluginRecoveryArchiveFormatMigrationPath? path;

  const PluginRecoveryArchiveMigrationPlan({
    required this.jobId,
    required this.disposition,
    required this.sourceFormatVersion,
    required this.targetFormatVersion,
    required this.sourceDigest,
    required this.archivedAt,
    required this.sourceRecord,
    required this.path,
  });

  bool get canMigrate =>
      disposition == PluginRecoveryArchiveMigrationDisposition.ready &&
      sourceRecord != null &&
      path != null;
}

final class PluginLifecycleRecoveryJobArchiveMigrationPlanner {
  final PluginLifecycleRecoveryJobArchive sourceArchive;
  final PluginLifecycleRecoveryJobArchiveMigrationRegistry registry;

  const PluginLifecycleRecoveryJobArchiveMigrationPlanner({
    required this.sourceArchive,
    required this.registry,
  });

  Future<PluginRecoveryArchiveMigrationPlan> inspect({
    required String jobId,
    int targetFormatVersion = PluginLifecycleRecoveryJobSnapshotCodec.formatVersion,
  }) async {
    final record = await sourceArchive.read(jobId);
    if (record == null) {
      return _plan(
        jobId: jobId,
        disposition: PluginRecoveryArchiveMigrationDisposition.missing,
        target: targetFormatVersion,
      );
    }
    if (record.job.schemaVersion != PluginLifecycleRecoveryJob.currentSchemaVersion) {
      return _plan(
        jobId: jobId,
        disposition: PluginRecoveryArchiveMigrationDisposition.unsupportedJobSchema,
        target: targetFormatVersion,
        record: record,
      );
    }
    if (record.job.jobId != jobId) {
      return _plan(
        jobId: jobId,
        disposition: PluginRecoveryArchiveMigrationDisposition.sourceChanged,
        target: targetFormatVersion,
        record: record,
      );
    }
    final path = registry.findPath(
      fromVersion: record.integrity.formatVersion,
      toVersion: targetFormatVersion,
    );
    if (path == null) {
      return _plan(
        jobId: jobId,
        disposition: PluginRecoveryArchiveMigrationDisposition.noMigrationPath,
        target: targetFormatVersion,
        record: record,
      );
    }
    return PluginRecoveryArchiveMigrationPlan(
      jobId: jobId,
      disposition: path.isEmpty
          ? PluginRecoveryArchiveMigrationDisposition.alreadyCurrent
          : PluginRecoveryArchiveMigrationDisposition.ready,
      sourceFormatVersion: record.integrity.formatVersion,
      targetFormatVersion: targetFormatVersion,
      sourceDigest: record.integrity.digest,
      archivedAt: record.archivedAt,
      sourceRecord: record,
      path: path,
    );
  }

  PluginRecoveryArchiveMigrationPlan _plan({
    required String jobId,
    required PluginRecoveryArchiveMigrationDisposition disposition,
    required int target,
    PluginLifecycleRecoveryJobArchiveRecord? record,
  }) => PluginRecoveryArchiveMigrationPlan(
    jobId: jobId,
    disposition: disposition,
    sourceFormatVersion: record?.integrity.formatVersion,
    targetFormatVersion: target,
    sourceDigest: record?.integrity.digest,
    archivedAt: record?.archivedAt,
    sourceRecord: record,
    path: null,
  );
}

/// Applies a previously inspected plan into a destination archive.
///
/// Source archives are never modified. The destination is written only after
/// every migration step and the new target-format digest have been produced.
final class PluginLifecycleRecoveryJobArchiveMigrationExecutor {
  final PluginLifecycleRecoveryJobArchive sourceArchive;
  final PluginLifecycleRecoveryJobArchive destinationArchive;
  final PluginLifecycleRecoveryJobDigestProvider digestProvider;
  final String digestAlgorithm;
  final PluginRecoveryArchiveSourceVerifier verifySource;
  final PluginLifecycleRecoveryJobSnapshotCodec codec;

  const PluginLifecycleRecoveryJobArchiveMigrationExecutor({
    required this.sourceArchive,
    required this.destinationArchive,
    required this.digestProvider,
    required this.digestAlgorithm,
    required this.verifySource,
    this.codec = const PluginLifecycleRecoveryJobSnapshotCodec(),
  });

  Future<PluginRecoveryArchiveMigrationDisposition> migrate(
    PluginRecoveryArchiveMigrationPlan plan,
  ) async {
    if (!plan.canMigrate) {
      throw StateError('Migration plan is not executable: ${plan.disposition.name}.');
    }
    if (plan.targetFormatVersion != PluginLifecycleRecoveryJobSnapshotCodec.formatVersion) {
      throw StateError('Only the runtime current archive format can be written.');
    }
    if (digestAlgorithm.trim().isEmpty) {
      throw ArgumentError.value(digestAlgorithm, 'digestAlgorithm');
    }

    final planned = plan.sourceRecord!;
    final latest = await sourceArchive.read(plan.jobId);
    if (latest == null || !_sameRecord(latest, planned)) {
      throw StateError('Archive source changed after migration inspection.');
    }
    if (!_isArchivable(latest.job) || !await verifySource(latest)) {
      throw StateError('Source archive is not terminal or failed integrity verification.');
    }

    var migrated = planned.job;
    var expectedVersion = plan.sourceFormatVersion;
    for (final step in plan.path!.steps) {
      if (step.fromVersion != expectedVersion) {
        throw StateError('Migration path is not contiguous.');
      }
      final before = migrated;
      migrated = step.migrate(before);
      _validateIdentity(before, migrated);
      expectedVersion = step.toVersion;
    }
    if (expectedVersion != plan.targetFormatVersion) {
      throw StateError('Migration path did not reach the requested target format.');
    }
    if (migrated.schemaVersion != PluginLifecycleRecoveryJob.currentSchemaVersion) {
      throw StateError('Migration produced an unsupported recovery-job schema.');
    }

    final payload = codec.encode(migrated, archivedAt: planned.archivedAt);
    final digest = await digestProvider.digest(
      algorithm: digestAlgorithm,
      canonicalPayload: payload,
    );
    final target = PluginLifecycleRecoveryJobArchiveRecord(
      job: migrated,
      archivedAt: planned.archivedAt,
      integrity: PluginLifecycleRecoveryJobArchiveIntegrity(
        formatVersion: plan.targetFormatVersion,
        algorithm: digestAlgorithm,
        digest: digest,
      ),
    );

    final inserted = await destinationArchive.putIfAbsent(target);
    final existing = await destinationArchive.read(plan.jobId);
    if (existing != null && !_sameRecord(existing, target)) {
      throw StateError('Destination contains a conflicting archive record.');
    }
    if (existing == null) {
      throw StateError('Destination did not retain the migrated archive record.');
    }
    if (inserted) return PluginRecoveryArchiveMigrationDisposition.imported;
    if (_sameRecord(existing, target)) {
      return PluginRecoveryArchiveMigrationDisposition.alreadyPresent;
    }
    throw StateError('Destination contains a conflicting archive record.');
  }

  static bool _isArchivable(PluginLifecycleRecoveryJob job) =>
      switch (job.status) {
        PluginRecoveryJobStatus.completed ||
        PluginRecoveryJobStatus.failed ||
        PluginRecoveryJobStatus.partiallyCompleted ||
        PluginRecoveryJobStatus.cancelled ||
        PluginRecoveryJobStatus.expired =>
          !job.steps.any((step) => step.status == PluginRecoveryJobStepStatus.running),
        PluginRecoveryJobStatus.planned ||
        PluginRecoveryJobStatus.running ||
        PluginRecoveryJobStatus.cancellationRequested ||
        PluginRecoveryJobStatus.interrupted ||
        PluginRecoveryJobStatus.manualReview => false,
      };

  static void _validateIdentity(
    PluginLifecycleRecoveryJob before,
    PluginLifecycleRecoveryJob after,
  ) {
    if (before.jobId != after.jobId ||
        before.idempotencyKey != after.idempotencyKey ||
        before.operationId != after.operationId ||
        before.action != after.action ||
        before.createdAt != after.createdAt ||
        before.initiatedBy != after.initiatedBy ||
        before.correlationId != after.correlationId ||
        before.orderedPluginIds.length != after.orderedPluginIds.length) {
      throw StateError('Archive migration must preserve recovery-job identity.');
    }
    for (var i = 0; i < before.orderedPluginIds.length; i++) {
      if (before.orderedPluginIds[i] != after.orderedPluginIds[i]) {
        throw StateError('Archive migration must preserve ordered plugin IDs.');
      }
    }
  }

  static bool _sameRecord(
    PluginLifecycleRecoveryJobArchiveRecord left,
    PluginLifecycleRecoveryJobArchiveRecord right,
  ) =>
      const PluginLifecycleRecoveryJobSnapshotCodec().encode(left.job, archivedAt: left.archivedAt) ==
          const PluginLifecycleRecoveryJobSnapshotCodec().encode(right.job, archivedAt: right.archivedAt) &&
      left.integrity.formatVersion == right.integrity.formatVersion &&
      left.integrity.algorithm == right.integrity.algorithm &&
      left.integrity.digest == right.integrity.digest &&
      left.archivedAt == right.archivedAt;
}
