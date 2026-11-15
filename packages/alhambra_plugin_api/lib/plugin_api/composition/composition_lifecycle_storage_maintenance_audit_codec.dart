import 'dart:convert';

import 'composition_lifecycle_storage_maintenance_coordinator.dart';
import 'composition_lifecycle_storage_maintenance.dart';

/// Versioned JSON codec for durable maintenance audit records.
///
/// Metrics must contain JSON-compatible values. Unsupported metric values fail
/// encoding rather than being silently stringified.
final class CompositionLifecycleStorageMaintenanceAuditJsonCodec {
  const CompositionLifecycleStorageMaintenanceAuditJsonCodec();

  static const int schemaVersion = 1;

  String encode(CompositionLifecycleStorageMaintenanceOperationRecord record) {
    final payload = <String, Object?>{
      'schemaVersion': schemaVersion,
      'operationId': record.operationId,
      'status': record.status.name,
      'requestedAt': record.requestedAt.toUtc().toIso8601String(),
      'startedAt': record.startedAt.toUtc().toIso8601String(),
      'completedAt': record.completedAt?.toUtc().toIso8601String(),
      'request': {
        'retainFrom': record.request.retainFrom?.toUtc().toIso8601String(),
        'maxEvents': record.request.maxEvents,
        'checkpoint': record.request.checkpoint,
      },
      'result': record.result == null
          ? null
          : {
              'startedAt': record.result!.startedAt.toUtc().toIso8601String(),
              'completedAt': record.result!.completedAt.toUtc().toIso8601String(),
              'recordsRemoved': record.result!.recordsRemoved,
              'checkpointRequested': record.result!.checkpointRequested,
              'checkpointCompleted': record.result!.checkpointCompleted,
              'warnings': record.result!.warnings,
              'metrics': record.result!.metrics,
            },
      'error': record.error,
    };
    return jsonEncode(payload);
  }

  CompositionLifecycleStorageMaintenanceOperationRecord decode(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) throw const FormatException('Audit record must be a JSON object.');
    final payload = Map<String, Object?>.from(decoded);
    if (payload['schemaVersion'] != schemaVersion) {
      throw FormatException('Unsupported maintenance audit schema: ${payload['schemaVersion']}.');
    }
    final rawRequest = payload['request'];
    if (rawRequest is! Map) throw const FormatException('Audit request is missing.');
    final request = Map<String, Object?>.from(rawRequest);
    final rawResult = payload['result'];
    CompositionLifecycleStorageMaintenanceResult? result;
    if (rawResult != null) {
      if (rawResult is! Map) throw const FormatException('Audit result must be an object.');
      final data = Map<String, Object?>.from(rawResult);
      final warnings = data['warnings'];
      final metrics = data['metrics'];
      if (warnings is! List || metrics is! Map) {
        throw const FormatException('Audit result warnings or metrics are invalid.');
      }
      result = CompositionLifecycleStorageMaintenanceResult(
        startedAt: DateTime.parse(data['startedAt'] as String),
        completedAt: DateTime.parse(data['completedAt'] as String),
        recordsRemoved: data['recordsRemoved'] as int?,
        checkpointRequested: data['checkpointRequested'] as bool,
        checkpointCompleted: data['checkpointCompleted'] as bool?,
        warnings: warnings.cast<String>(),
        metrics: Map<String, Object?>.from(metrics),
      );
    }
    return CompositionLifecycleStorageMaintenanceOperationRecord(
      operationId: payload['operationId'] as String,
      status: CompositionLifecycleStorageMaintenanceOperationStatus.values
          .byName(payload['status'] as String),
      requestedAt: DateTime.parse(payload['requestedAt'] as String),
      startedAt: DateTime.parse(payload['startedAt'] as String),
      completedAt: payload['completedAt'] == null
          ? null
          : DateTime.parse(payload['completedAt'] as String),
      request: CompositionLifecycleStorageMaintenanceRequest(
        retainFrom: request['retainFrom'] == null
            ? null
            : DateTime.parse(request['retainFrom'] as String),
        maxEvents: request['maxEvents'] as int?,
        checkpoint: request['checkpoint'] as bool? ?? false,
      ),
      result: result,
      error: payload['error'] as String?,
    );
  }
}
