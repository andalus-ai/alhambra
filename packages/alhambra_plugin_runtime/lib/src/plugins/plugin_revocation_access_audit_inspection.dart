import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'plugin_revocation_admin_operations.dart';

/// Validated, bounded query for the durable administrative access-audit log.
final class PluginRevocationAccessAuditQuery {
  final String scopeId;
  final int limit;
  final DateTime? fromInclusive;
  final DateTime? toExclusive;

  PluginRevocationAccessAuditQuery({
    required this.scopeId,
    this.limit = 100,
    this.fromInclusive,
    this.toExclusive,
  }) {
    if (scopeId.trim().isEmpty) {
      throw ArgumentError.value(scopeId, 'scopeId');
    }
    if (limit < 1 || limit > 200) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 200.');
    }
    if (fromInclusive != null &&
        toExclusive != null &&
        !fromInclusive!.isBefore(toExclusive!)) {
      throw ArgumentError('fromInclusive must be earlier than toExclusive.');
    }
  }
}

/// Result of an authorized, scope-filtered access-audit inspection.
final class PluginRevocationAccessAuditResult {
  final String scopeId;
  final List<PluginRevocationOperationsAccessAudit> records;

  PluginRevocationAccessAuditResult({
    required this.scopeId,
    required Iterable<PluginRevocationOperationsAccessAudit> records,
  }) : records = List.unmodifiable(records);
}

/// Host authorization port dedicated to access-audit log inspection.
///
/// This is intentionally separate from ordinary revocation operations
/// inspection: hosts can grant access to operational state without granting
/// access to the security audit trail.
abstract interface class PluginRevocationAccessAuditAuthorizer {
  Future<bool> canInspectAccessAudit({
    required PluginRevocationOperationsPrincipal principal,
    required String scopeId,
  });
}

/// Authorized read boundary for the durable revocation operations access log.
///
/// The host supplies an authenticated principal, scope authorization policy,
/// an append-only audit sink, and an optional durable inspection adapter.
/// Every attempt is appended to the audit sink before the read is attempted.
/// A failed append, denied authorization, or missing read adapter fails closed.
///
/// The inspection event is written with resource `accessAudit`; it is not
/// recursively inspected by this service. The sink's append operation must
/// remain a low-level persistence operation and must never call this service.
final class PluginRevocationAccessAuditInspectionService {
  static const String auditResource = 'accessAudit';

  final PluginRevocationAccessAuditAuthorizer authorizer;
  final PluginRevocationOperationsAccessAuditStore accessAuditStore;
  final PluginRevocationOperationsAccessAuditInspectionStore? inspectionStore;
  final DateTime Function() clock;

  PluginRevocationAccessAuditInspectionService({
    required this.authorizer,
    required this.accessAuditStore,
    required this.inspectionStore,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  Future<PluginRevocationAccessAuditResult> inspect({
    required PluginRevocationOperationsPrincipal principal,
    required PluginRevocationAccessAuditQuery query,
  }) async {
    final allowed = await authorizer.canInspectAccessAudit(
      principal: principal,
      scopeId: query.scopeId,
    );

    await accessAuditStore.append(PluginRevocationOperationsAccessAudit(
      actorId: principal.actorId,
      scopeId: query.scopeId,
      decision: allowed
          ? PluginRevocationOperationsAccessDecision.allowed
          : PluginRevocationOperationsAccessDecision.denied,
      denialCode: allowed ? null : 'access_audit_inspection_denied',
      occurredAt: clock().toUtc(),
      resource: auditResource,
      pageSize: query.limit,
      continuationRequested: false,
      queryFingerprint: _fingerprint(query),
    ));

    if (!allowed) {
      throw const PluginRevocationOperationsAccessDeniedException();
    }

    final store = inspectionStore;
    if (store == null) {
      throw const PluginRevocationAccessAuditInspectionUnavailableException();
    }

    final records = await store.readAccessAudits(
      scopeId: query.scopeId,
      limit: query.limit,
      fromInclusive: query.fromInclusive,
      toExclusive: query.toExclusive,
    );
    return PluginRevocationAccessAuditResult(
      scopeId: query.scopeId,
      records: records,
    );
  }

  String _fingerprint(PluginRevocationAccessAuditQuery query) {
    final canonical = jsonEncode([
      auditResource,
      query.scopeId,
      query.fromInclusive?.toUtc().toIso8601String() ?? '',
      query.toExclusive?.toUtc().toIso8601String() ?? '',
      query.limit,
    ]);
    return sha256.convert(utf8.encode(canonical)).toString();
  }
}

/// Raised when durable access-audit inspection is not configured.
final class PluginRevocationAccessAuditInspectionUnavailableException
    implements Exception {
  const PluginRevocationAccessAuditInspectionUnavailableException();

  @override
  String toString() =>
      'Durable plugin revocation access-audit inspection is not configured.';
}
