import 'dart:convert';

import 'plugin_lifecycle_recovery_job.dart';
import 'plugin_lifecycle_recovery_job_archive.dart';
import 'plugin_lifecycle_recovery_job_archive_integrity.dart';
import 'plugin_lifecycle_recovery_job_archive_integrity_metadata.dart';

final class PluginRecoveryArchivePackageManifest {
  static const int currentFormatVersion = 1;
  final int formatVersion;
  final String packageId;
  final DateTime createdAt;
  final String producer;
  final int recordCount;

  PluginRecoveryArchivePackageManifest({
    required this.formatVersion,
    required this.packageId,
    required DateTime createdAt,
    required this.producer,
    required this.recordCount,
  }) : createdAt = createdAt.toUtc() {
    if (formatVersion != currentFormatVersion) {
      throw ArgumentError.value(formatVersion, 'formatVersion');
    }
    if (packageId.trim().isEmpty) throw ArgumentError.value(packageId, 'packageId');
    if (producer.trim().isEmpty) throw ArgumentError.value(producer, 'producer');
    if (recordCount < 1) throw ArgumentError.value(recordCount, 'recordCount');
  }
}

final class PluginRecoveryArchivePackage {
  final PluginRecoveryArchivePackageManifest manifest;
  final List<PluginLifecycleRecoveryJobArchiveRecord> records;
  final String digestAlgorithm;
  final String digest;

  PluginRecoveryArchivePackage({
    required this.manifest,
    required Iterable<PluginLifecycleRecoveryJobArchiveRecord> records,
    required this.digestAlgorithm,
    required this.digest,
  }) : records = List.unmodifiable(records) {
    if (this.records.length != manifest.recordCount) {
      throw ArgumentError('Manifest recordCount does not match package records.');
    }
    if (digestAlgorithm.trim().isEmpty) {
      throw ArgumentError.value(digestAlgorithm, 'digestAlgorithm');
    }
    if (digest.trim().isEmpty) throw ArgumentError.value(digest, 'digest');
    if (this.records.map((record) => record.job.jobId).toSet().length != this.records.length) {
      throw ArgumentError('A package cannot contain duplicate job IDs.');
    }
  }
}

final class PluginRecoveryArchivePackageCodec {
  const PluginRecoveryArchivePackageCodec();

  String encodePayload({
    required PluginRecoveryArchivePackageManifest manifest,
    required Iterable<PluginLifecycleRecoveryJobArchiveRecord> records,
  }) {
    final ordered = records.toList()
      ..sort((a, b) => a.job.jobId.compareTo(b.job.jobId));
    return jsonEncode({
      'manifest': {
        'formatVersion': manifest.formatVersion,
        'packageId': manifest.packageId,
        'createdAt': manifest.createdAt.toUtc().toIso8601String(),
        'producer': manifest.producer,
        'recordCount': manifest.recordCount,
      },
      'records': ordered.map(_recordToJson).toList(growable: false),
    });
  }

  String encode(PluginRecoveryArchivePackage archivePackage) => jsonEncode({
    'payload': jsonDecode(encodePayload(
      manifest: archivePackage.manifest,
      records: archivePackage.records,
    )),
    'integrity': {
      'algorithm': archivePackage.digestAlgorithm,
      'digest': archivePackage.digest,
    },
  });

  PluginRecoveryArchivePackage decode(String source) {
    final root = _map(jsonDecode(source), 'package');
    final payload = _map(root['payload'], 'payload');
    final manifestJson = _map(payload['manifest'], 'manifest');
    final manifest = PluginRecoveryArchivePackageManifest(
      formatVersion: _int(manifestJson['formatVersion'], 'formatVersion'),
      packageId: _string(manifestJson['packageId'], 'packageId'),
      createdAt: _date(manifestJson['createdAt'], 'createdAt')!,
      producer: _string(manifestJson['producer'], 'producer'),
      recordCount: _int(manifestJson['recordCount'], 'recordCount'),
    );
    final rawRecords = payload['records'];
    if (rawRecords is! List) throw const FormatException('records must be an array.');
    final records = rawRecords.map(_recordFromJson).toList(growable: false);
    final integrity = _map(root['integrity'], 'integrity');
    return PluginRecoveryArchivePackage(
      manifest: manifest,
      records: records,
      digestAlgorithm: _string(integrity['algorithm'], 'algorithm'),
      digest: _string(integrity['digest'], 'digest'),
    );
  }

  static Map<String, Object?> _recordToJson(
    PluginLifecycleRecoveryJobArchiveRecord record,
  ) => {
    'archivedAt': record.archivedAt.toUtc().toIso8601String(),
    'integrity': {
      'formatVersion': record.integrity.formatVersion,
      'algorithm': record.integrity.algorithm,
      'digest': record.integrity.digest,
    },
    'job': _jobToJson(record.job),
  };

  static PluginLifecycleRecoveryJobArchiveRecord _recordFromJson(Object? value) {
    final json = _map(value, 'record');
    final integrity = _map(json['integrity'], 'record.integrity');
    return PluginLifecycleRecoveryJobArchiveRecord(
      job: _jobFromJson(json['job']),
      archivedAt: _date(json['archivedAt'], 'archivedAt')!,
      integrity: PluginLifecycleRecoveryJobArchiveIntegrity(
        formatVersion: _int(integrity['formatVersion'], 'integrity.formatVersion'),
        algorithm: _string(integrity['algorithm'], 'integrity.algorithm'),
        digest: _string(integrity['digest'], 'integrity.digest'),
      ),
    );
  }

  static Map<String, Object?> _jobToJson(PluginLifecycleRecoveryJob job) => {
    'schemaVersion': job.schemaVersion,
    'jobId': job.jobId,
    'idempotencyKey': job.idempotencyKey,
    'operationId': job.operationId,
    'action': job.action.name,
    'orderedPluginIds': job.orderedPluginIds,
    'steps': job.steps.map((step) => {
      'pluginId': step.pluginId,
      'ordinal': step.ordinal,
      'status': step.status.name,
      'expectedCheckpointOperationId': step.expectedCheckpointOperationId,
      'expectedCheckpointSequence': step.expectedCheckpointSequence,
      'executionOperationId': step.executionOperationId,
      'startedAt': _dateToJson(step.startedAt),
      'completedAt': _dateToJson(step.completedAt),
      'failureCode': step.failureCode,
      'failureSummary': step.failureSummary,
    }).toList(growable: false),
    'status': job.status.name,
    'revision': job.revision,
    'createdAt': job.createdAt.toUtc().toIso8601String(),
    'updatedAt': job.updatedAt.toUtc().toIso8601String(),
    'initiatedBy': job.initiatedBy,
    'correlationId': job.correlationId,
    'failureCode': job.failureCode,
    'failureSummary': job.failureSummary,
    'cancellationRequestedAt': _dateToJson(job.cancellationRequestedAt),
    'expiresAt': _dateToJson(job.expiresAt),
    'expiredAt': _dateToJson(job.expiredAt),
  };

  static PluginLifecycleRecoveryJob _jobFromJson(Object? value) {
    final json = _map(value, 'job');
    final idsValue = json['orderedPluginIds'];
    final stepsValue = json['steps'];
    if (idsValue is! List || idsValue.any((id) => id is! String)) {
      throw const FormatException('orderedPluginIds must be an array of strings.');
    }
    if (stepsValue is! List) throw const FormatException('steps must be an array.');
    return PluginLifecycleRecoveryJob(
      schemaVersion: _int(json['schemaVersion'], 'schemaVersion'),
      jobId: _string(json['jobId'], 'jobId'),
      idempotencyKey: _string(json['idempotencyKey'], 'idempotencyKey'),
      operationId: _string(json['operationId'], 'operationId'),
      action: _enumValue(PluginRecoveryJobAction.values, json['action'], 'action'),
      orderedPluginIds: idsValue.cast<String>(),
      steps: stepsValue.map((value) {
        final step = _map(value, 'step');
        return PluginRecoveryJobStep(
          pluginId: _string(step['pluginId'], 'step.pluginId'),
          ordinal: _int(step['ordinal'], 'step.ordinal'),
          status: _enumValue(PluginRecoveryJobStepStatus.values, step['status'], 'step.status'),
          expectedCheckpointOperationId: _optionalString(step['expectedCheckpointOperationId']),
          expectedCheckpointSequence: _optionalInt(step['expectedCheckpointSequence']),
          executionOperationId: _optionalString(step['executionOperationId']),
          startedAt: _date(step['startedAt'], 'step.startedAt'),
          completedAt: _date(step['completedAt'], 'step.completedAt'),
          failureCode: _optionalString(step['failureCode']),
          failureSummary: _optionalString(step['failureSummary']),
        );
      }),
      status: _enumValue(PluginRecoveryJobStatus.values, json['status'], 'status'),
      revision: _int(json['revision'], 'revision'),
      createdAt: _date(json['createdAt'], 'createdAt')!,
      updatedAt: _date(json['updatedAt'], 'updatedAt')!,
      initiatedBy: _optionalString(json['initiatedBy']),
      correlationId: _optionalString(json['correlationId']),
      failureCode: _optionalString(json['failureCode']),
      failureSummary: _optionalString(json['failureSummary']),
      cancellationRequestedAt: _date(json['cancellationRequestedAt'], 'cancellationRequestedAt'),
      expiresAt: _date(json['expiresAt'], 'expiresAt'),
      expiredAt: _date(json['expiredAt'], 'expiredAt'),
    );
  }

  static Map<String, Object?> _map(Object? value, String field) {
    if (value is! Map) throw FormatException('$field must be an object.');
    return value.map((key, value) {
      if (key is! String) throw FormatException('$field keys must be strings.');
      return MapEntry(key, value);
    });
  }

  static String _string(Object? value, String field) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$field must be a non-empty string.');
    }
    return value;
  }

  static int _int(Object? value, String field) {
    if (value is! int) throw FormatException('$field must be an integer.');
    return value;
  }

  static String? _optionalString(Object? value) {
    if (value == null) return null;
    if (value is! String) throw const FormatException('Expected string or null.');
    return value;
  }

  static int? _optionalInt(Object? value) {
    if (value == null) return null;
    if (value is! int) throw const FormatException('Expected integer or null.');
    return value;
  }

  static DateTime? _date(Object? value, String field) {
    if (value == null) return null;
    if (value is! String) throw FormatException('$field must be an ISO-8601 string.');
    try {
      return DateTime.parse(value).toUtc();
    } on FormatException {
      throw FormatException('$field is not a valid ISO-8601 timestamp.');
    }
  }

  static String? _dateToJson(DateTime? value) => value?.toUtc().toIso8601String();

  static T _enumValue<T extends Enum>(List<T> values, Object? value, String field) {
    if (value is! String) throw FormatException('$field must be a string.');
    for (final candidate in values) {
      if (candidate.name == value) return candidate;
    }
    throw FormatException('Unknown $field value "$value".');
  }
}

final class PluginRecoveryArchivePackageExporter {
  final PluginLifecycleRecoveryJobDigestProvider digestProvider;
  final String digestAlgorithm;
  final PluginRecoveryArchivePackageCodec codec;
  final PluginLifecycleRecoveryJobSnapshotCodec snapshotCodec;

  const PluginRecoveryArchivePackageExporter({
    required this.digestProvider,
    required this.digestAlgorithm,
    this.codec = const PluginRecoveryArchivePackageCodec(),
    this.snapshotCodec = const PluginLifecycleRecoveryJobSnapshotCodec(),
  });

  Future<PluginRecoveryArchivePackage> create({
    required String packageId,
    required String producer,
    required DateTime createdAt,
    required Iterable<PluginLifecycleRecoveryJobArchiveRecord> records,
  }) async {
    final values = records.toList(growable: false);
    if (values.isEmpty) throw ArgumentError('Cannot export an empty archive package.');
    for (final record in values) {
      if (record.job.schemaVersion != PluginLifecycleRecoveryJob.currentSchemaVersion ||
          record.integrity.formatVersion != PluginLifecycleRecoveryJobSnapshotCodec.formatVersion ||
          !_isTerminal(record.job)) {
        throw StateError('Package export accepts only current-schema terminal archive records.');
      }
      final actualRecordDigest = await digestProvider.digest(
        algorithm: record.integrity.algorithm,
        canonicalPayload: snapshotCodec.encode(record.job, archivedAt: record.archivedAt),
      );
      if (actualRecordDigest != record.integrity.digest) {
        throw StateError('Cannot export an archive record with an invalid digest.');
      }
    }
    final manifest = PluginRecoveryArchivePackageManifest(
      formatVersion: PluginRecoveryArchivePackageManifest.currentFormatVersion,
      packageId: packageId,
      createdAt: createdAt,
      producer: producer,
      recordCount: values.length,
    );
    final payload = codec.encodePayload(manifest: manifest, records: values);
    final digest = await digestProvider.digest(
      algorithm: digestAlgorithm,
      canonicalPayload: payload,
    );
    return PluginRecoveryArchivePackage(
      manifest: manifest,
      records: values,
      digestAlgorithm: digestAlgorithm,
      digest: digest,
    );
  }
}

enum PluginRecoveryArchivePackageImportDisposition {
  ready,
  invalidPackageDigest,
  unsupportedPackageFormat,
  invalidRecord,
  destinationConflict,
  alreadyPresent,
  imported,
  partiallyImported,
}

final class PluginRecoveryArchivePackageImportPlan {
  final PluginRecoveryArchivePackage archivePackage;
  final PluginRecoveryArchivePackageImportDisposition disposition;
  final List<String> validJobIds;
  final List<String> conflictingJobIds;
  final List<String> alreadyPresentJobIds;
  final List<String> invalidJobIds;

  PluginRecoveryArchivePackageImportPlan({
    required this.archivePackage,
    required this.disposition,
    required Iterable<String> validJobIds,
    required Iterable<String> conflictingJobIds,
    required Iterable<String> alreadyPresentJobIds,
    required Iterable<String> invalidJobIds,
  }) : validJobIds = List.unmodifiable(validJobIds),
       conflictingJobIds = List.unmodifiable(conflictingJobIds),
       alreadyPresentJobIds = List.unmodifiable(alreadyPresentJobIds),
       invalidJobIds = List.unmodifiable(invalidJobIds);

  bool get canImport =>
      disposition == PluginRecoveryArchivePackageImportDisposition.ready ||
      disposition == PluginRecoveryArchivePackageImportDisposition.alreadyPresent;
}

final class PluginRecoveryArchivePackageImporter {
  final PluginLifecycleRecoveryJobArchive destinationArchive;
  final PluginLifecycleRecoveryJobDigestProvider digestProvider;
  final PluginRecoveryArchivePackageCodec packageCodec;
  final PluginLifecycleRecoveryJobSnapshotCodec snapshotCodec;

  const PluginRecoveryArchivePackageImporter({
    required this.destinationArchive,
    required this.digestProvider,
    this.packageCodec = const PluginRecoveryArchivePackageCodec(),
    this.snapshotCodec = const PluginLifecycleRecoveryJobSnapshotCodec(),
  });

  Future<PluginRecoveryArchivePackageImportPlan> inspect(
    PluginRecoveryArchivePackage archivePackage,
  ) async {
    if (archivePackage.manifest.formatVersion !=
        PluginRecoveryArchivePackageManifest.currentFormatVersion) {
      return _plan(archivePackage, PluginRecoveryArchivePackageImportDisposition.unsupportedPackageFormat);
    }
    final payload = packageCodec.encodePayload(
      manifest: archivePackage.manifest,
      records: archivePackage.records,
    );
    final packageDigest = await digestProvider.digest(
      algorithm: archivePackage.digestAlgorithm,
      canonicalPayload: payload,
    );
    if (packageDigest != archivePackage.digest) {
      return _plan(archivePackage, PluginRecoveryArchivePackageImportDisposition.invalidPackageDigest);
    }

    final valid = <String>[];
    final conflicts = <String>[];
    final present = <String>[];
    final invalid = <String>[];
    for (final record in archivePackage.records) {
      final id = record.job.jobId;
      if (record.job.schemaVersion != PluginLifecycleRecoveryJob.currentSchemaVersion ||
          record.integrity.formatVersion != PluginLifecycleRecoveryJobSnapshotCodec.formatVersion ||
          !_isTerminal(record.job)) {
        invalid.add(id);
        continue;
      }
      final actual = await digestProvider.digest(
        algorithm: record.integrity.algorithm,
        canonicalPayload: snapshotCodec.encode(record.job, archivedAt: record.archivedAt),
      );
      if (actual != record.integrity.digest) {
        invalid.add(id);
        continue;
      }
      final existing = await destinationArchive.read(id);
      if (existing == null) {
        valid.add(id);
      } else if (_sameRecord(existing, record, snapshotCodec)) {
        present.add(id);
      } else {
        conflicts.add(id);
      }
    }
    final disposition = invalid.isNotEmpty
        ? PluginRecoveryArchivePackageImportDisposition.invalidRecord
        : conflicts.isNotEmpty
            ? PluginRecoveryArchivePackageImportDisposition.destinationConflict
            : valid.isEmpty
                ? PluginRecoveryArchivePackageImportDisposition.alreadyPresent
                : PluginRecoveryArchivePackageImportDisposition.ready;
    return PluginRecoveryArchivePackageImportPlan(
      archivePackage: archivePackage,
      disposition: disposition,
      validJobIds: valid,
      conflictingJobIds: conflicts,
      alreadyPresentJobIds: present,
      invalidJobIds: invalid,
    );
  }

  Future<PluginRecoveryArchivePackageImportReport> importPackage(
    PluginRecoveryArchivePackageImportPlan plan,
  ) async {
    if (!plan.canImport) {
      throw StateError('Package import is blocked: \${plan.disposition.name}.');
    }
    final fresh = await inspect(plan.archivePackage);
    final approvedIds = [...plan.validJobIds, ...plan.alreadyPresentJobIds];
    final currentIds = [...fresh.validJobIds, ...fresh.alreadyPresentJobIds];
    if (!fresh.canImport ||
        !_sameIds(approvedIds, currentIds) ||
        fresh.conflictingJobIds.isNotEmpty ||
        fresh.invalidJobIds.isNotEmpty) {
      throw StateError('Package or destination changed after inspection.');
    }

    final imported = <String>[];
    final present = [...fresh.alreadyPresentJobIds];
    final conflicts = <String>[];
    final byId = {for (final record in plan.archivePackage.records) record.job.jobId: record};
    for (final id in fresh.validJobIds) {
      final record = byId[id]!;
      if (await destinationArchive.putIfAbsent(record)) {
        final stored = await destinationArchive.read(id);
        if (stored == null || !_sameRecord(stored, record, snapshotCodec)) {
          conflicts.add(id);
          break;
        }
        imported.add(id);
      } else {
        final stored = await destinationArchive.read(id);
        if (stored != null && _sameRecord(stored, record, snapshotCodec)) {
          present.add(id);
        } else {
          conflicts.add(id);
          break;
        }
      }
    }
    final disposition = conflicts.isNotEmpty
        ? PluginRecoveryArchivePackageImportDisposition.partiallyImported
        : imported.isEmpty
            ? PluginRecoveryArchivePackageImportDisposition.alreadyPresent
            : PluginRecoveryArchivePackageImportDisposition.imported;
    return PluginRecoveryArchivePackageImportReport(
      disposition: disposition,
      importedJobIds: imported,
      alreadyPresentJobIds: present,
      conflictingJobIds: conflicts,
    );
  }

  PluginRecoveryArchivePackageImportPlan _plan(
    PluginRecoveryArchivePackage archivePackage,
    PluginRecoveryArchivePackageImportDisposition disposition,
  ) => PluginRecoveryArchivePackageImportPlan(
    archivePackage: archivePackage,
    disposition: disposition,
    validJobIds: const [],
    conflictingJobIds: const [],
    alreadyPresentJobIds: const [],
    invalidJobIds: const [],
  );
}

final class PluginRecoveryArchivePackageImportReport {
  final PluginRecoveryArchivePackageImportDisposition disposition;
  final List<String> importedJobIds;
  final List<String> alreadyPresentJobIds;
  final List<String> conflictingJobIds;

  PluginRecoveryArchivePackageImportReport({
    required this.disposition,
    required Iterable<String> importedJobIds,
    required Iterable<String> alreadyPresentJobIds,
    required Iterable<String> conflictingJobIds,
  }) : importedJobIds = List.unmodifiable(importedJobIds),
       alreadyPresentJobIds = List.unmodifiable(alreadyPresentJobIds),
       conflictingJobIds = List.unmodifiable(conflictingJobIds);
}

bool _isTerminal(PluginLifecycleRecoveryJob job) => switch (job.status) {
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

bool _sameRecord(
  PluginLifecycleRecoveryJobArchiveRecord left,
  PluginLifecycleRecoveryJobArchiveRecord right,
  PluginLifecycleRecoveryJobSnapshotCodec codec,
) =>
    codec.encode(left.job, archivedAt: left.archivedAt) ==
        codec.encode(right.job, archivedAt: right.archivedAt) &&
    left.archivedAt == right.archivedAt &&
    left.integrity.formatVersion == right.integrity.formatVersion &&
    left.integrity.algorithm == right.integrity.algorithm &&
    left.integrity.digest == right.integrity.digest;
