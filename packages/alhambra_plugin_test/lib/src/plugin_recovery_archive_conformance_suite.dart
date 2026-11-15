import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

/// Builds isolated archive fixtures. For a given [jobId], variants must
/// produce different job snapshots when [variant] differs.
typedef PluginRecoveryArchiveFixtureBuilder =
    PluginLifecycleRecoveryJobArchiveRecord Function(String jobId, int variant);

enum PluginRecoveryArchiveConformanceStatus { passed, failed, skipped }

/// One behavioral assertion from a recovery archive adapter run.
final class PluginRecoveryArchiveConformanceCheck {
  final String name;
  final PluginRecoveryArchiveConformanceStatus status;
  final String detail;

  const PluginRecoveryArchiveConformanceCheck({
    required this.name,
    required this.status,
    required this.detail,
  });
}

/// Immutable result of running the archive adapter behavioral contract.
final class PluginRecoveryArchiveConformanceReport {
  final List<PluginRecoveryArchiveConformanceCheck> checks;

  PluginRecoveryArchiveConformanceReport(
    Iterable<PluginRecoveryArchiveConformanceCheck> checks,
  ) : checks = List.unmodifiable(checks);

  bool get isConformant => checks.every(
    (check) => check.status != PluginRecoveryArchiveConformanceStatus.failed,
  );

  int get passedCount => checks
      .where((check) => check.status == PluginRecoveryArchiveConformanceStatus.passed)
      .length;

  int get failedCount => checks
      .where((check) => check.status == PluginRecoveryArchiveConformanceStatus.failed)
      .length;

  int get skippedCount => checks
      .where((check) => check.status == PluginRecoveryArchiveConformanceStatus.skipped)
      .length;
}

/// Exercises the persistence-neutral recovery archive contract against a
/// disposable adapter namespace.
///
/// The [runId] must be unique for each invocation. The fixture builder must
/// return terminal jobs and must vary the persisted job snapshot by variant.
/// This suite performs writes and, when supported, deletes its own fixtures.
/// It is a behavioral test utility, not proof of cross-process atomicity:
/// production adapters still need database-specific concurrency integration
/// tests against independent connections or workers.
final class PluginRecoveryArchiveConformanceSuite {
  const PluginRecoveryArchiveConformanceSuite();

  Future<PluginRecoveryArchiveConformanceReport> verify({
    required PluginLifecycleRecoveryJobArchive archive,
    required PluginRecoveryArchiveFixtureBuilder fixtureBuilder,
    required String runId,
    int concurrentWriters = 8,
  }) async {
    if (runId.trim().isEmpty || runId.contains('/') || runId.contains(' ')) {
      throw ArgumentError.value(runId, 'runId', 'Use a non-empty, path-safe unique value.');
    }
    if (concurrentWriters < 2) {
      throw ArgumentError.value(concurrentWriters, 'concurrentWriters');
    }

    final checks = <PluginRecoveryArchiveConformanceCheck>[];
    Future<void> record(
      String name,
      Future<bool> Function() assertion, {
      required String success,
      required String failure,
    }) async {
      try {
        final passed = await assertion();
        checks.add(PluginRecoveryArchiveConformanceCheck(
          name: name,
          status: passed
              ? PluginRecoveryArchiveConformanceStatus.passed
              : PluginRecoveryArchiveConformanceStatus.failed,
          detail: passed ? success : failure,
        ));
      } on Object catch (error) {
        checks.add(PluginRecoveryArchiveConformanceCheck(
          name: name,
          status: PluginRecoveryArchiveConformanceStatus.failed,
          detail: 'Adapter threw ${error.runtimeType}.',
        ));
      }
    }

    final concurrentId = 'archive-conformance-$runId-concurrent';
    final concurrentRecord = fixtureBuilder(concurrentId, 0);
    if (concurrentRecord.job.jobId != concurrentId) {
      throw ArgumentError('Fixture builder must preserve the requested job ID.');
    }

    final writes = await Future.wait(List.generate(
      concurrentWriters,
      (_) => archive.putIfAbsent(concurrentRecord),
    ));
    await record(
      'concurrent insert-if-absent has one winner',
      () async => writes.where((inserted) => inserted).length == 1,
      success: 'Exactly one concurrent insert succeeded.',
      failure: 'Expected exactly one successful insert; got ${writes.where((v) => v).length}.',
    );

    await record(
      'read returns the inserted snapshot',
      () async {
        final stored = await archive.read(concurrentId);
        return stored != null &&
            _sameSnapshot(stored, concurrentRecord) &&
            stored.integrity.digest == concurrentRecord.integrity.digest &&
            stored.integrity.algorithm == concurrentRecord.integrity.algorithm &&
            stored.archivedAt == concurrentRecord.archivedAt;
      },
      success: 'The stored record matches the inserted snapshot and integrity envelope.',
      failure: 'The stored record is missing or differs from the inserted record.',
    );

    await record(
      'identical duplicate is rejected without replacement',
      () async {
        final inserted = await archive.putIfAbsent(concurrentRecord);
        final stored = await archive.read(concurrentId);
        return !inserted && stored != null && _sameRecord(stored, concurrentRecord);
      },
      success: 'Duplicate insertion returned false and preserved the original record.',
      failure: 'Duplicate insertion replaced or altered the original record.',
    );

    await record(
      'conflicting snapshot is rejected',
      () async {
        final conflicting = fixtureBuilder(concurrentId, 1);
        if (conflicting.job.jobId != concurrentId ||
            _sameSnapshot(conflicting, concurrentRecord)) return false;
        final inserted = await archive.putIfAbsent(conflicting);
        final stored = await archive.read(concurrentId);
        return !inserted && stored != null && _sameRecord(stored, concurrentRecord);
      },
      success: 'A different snapshot with the same job ID was rejected.',
      failure: 'The adapter accepted or stored a conflicting snapshot.',
    );

    if (archive is PluginLifecycleRecoveryJobArchivePurgeStore) {
      final purgeId = 'archive-conformance-$runId-purge';
      final purgeRecord = fixtureBuilder(purgeId, 0);
      if (purgeRecord.job.jobId != purgeId) {
        throw ArgumentError('Fixture builder must preserve the requested purge job ID.');
      }
      await record(
        'purge rejects a mismatched digest',
        () async {
          final inserted = await archive.putIfAbsent(purgeRecord);
          if (!inserted) return false;
          final deleted = await archive.deleteIfDigestMatches(
            jobId: purgeId,
            expectedDigest: '${purgeRecord.integrity.digest}-mismatch',
          );
          final stored = await archive.read(purgeId);
          return !deleted && stored != null;
        },
        success: 'A mismatched digest did not delete the archive.',
        failure: 'A mismatched digest deleted or changed the archive.',
      );
      await record(
        'purge atomically matches the expected digest',
        () async {
          final stored = await archive.read(purgeId);
          if (stored == null) return false;
          final deleted = await archive.deleteIfDigestMatches(
            jobId: purgeId,
            expectedDigest: purgeRecord.integrity.digest,
          );
          return deleted && await archive.read(purgeId) == null;
        },
        success: 'The matching digest deleted the archive and subsequent read was empty.',
        failure: 'The matching digest did not atomically remove the archive.',
      );
    } else {
      checks.add(const PluginRecoveryArchiveConformanceCheck(
        name: 'digest-guarded purge',
        status: PluginRecoveryArchiveConformanceStatus.skipped,
        detail: 'Adapter does not implement the optional purge-store contract.',
      ));
    }

    return PluginRecoveryArchiveConformanceReport(checks);
  }

  bool _sameSnapshot(
    PluginLifecycleRecoveryJobArchiveRecord left,
    PluginLifecycleRecoveryJobArchiveRecord right,
  ) => const PluginLifecycleRecoveryJobSnapshotCodec().encode(left.job) ==
      const PluginLifecycleRecoveryJobSnapshotCodec().encode(right.job);

  bool _sameRecord(
    PluginLifecycleRecoveryJobArchiveRecord left,
    PluginLifecycleRecoveryJobArchiveRecord right,
  ) => _sameSnapshot(left, right) &&
      left.archivedAt == right.archivedAt &&
      left.integrity.formatVersion == right.integrity.formatVersion &&
      left.integrity.algorithm == right.integrity.algorithm &&
      left.integrity.digest == right.integrity.digest;
}
