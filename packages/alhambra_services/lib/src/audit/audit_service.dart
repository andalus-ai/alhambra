import 'package:alhambra_core/alhambra_core.dart';

/// A governance/security-significant action recorded for compliance.
///
/// Distinct from logging: audit captures *who did what to what*, not operational metrics.
final class AuditEvent {
  final String id;
  final DateTime timestamp;
  final String action;
  final String resourceType;
  final String resourceId;
  final UserId? actorId;
  final OrganizationId? organizationId;
  final bool successful;
  final Map<String, Object?> metadata;

  const AuditEvent({
    required this.id,
    required this.timestamp,
    required this.action,
    required this.resourceType,
    required this.resourceId,
    this.actorId,
    this.organizationId,
    required this.successful,
    this.metadata = const {},
  });

  @override
  String toString() =>
      'AuditEvent($id, $action on $resourceType/$resourceId, actor: $actorId, ok: $successful)';
}

/// Filter for querying the audit log.
final class AuditQuery {
  final UserId? actorId;
  final OrganizationId? organizationId;
  final String? action;
  final String? resourceType;
  final String? resourceId;
  final DateTime? from;
  final DateTime? to;
  final int limit;
  final int offset;

  const AuditQuery({
    this.actorId,
    this.organizationId,
    this.action,
    this.resourceType,
    this.resourceId,
    this.from,
    this.to,
    this.limit = 50,
    this.offset = 0,
  });
}

/// Platform audit service.
abstract interface class AuditService {
  /// Records a security/governance event.
  Future<void> record(AuditEvent event);

  /// Queries the audit log with the given filter.
  Future<List<AuditEvent>> query(AuditQuery query);
}

// ---------------------------------------------------------------------------
// In-memory implementation
// ---------------------------------------------------------------------------

/// In-memory [AuditService] for tests.
final class InMemoryAuditService implements AuditService {
  final _events = <AuditEvent>[];

  @override
  Future<void> record(AuditEvent event) async => _events.add(event);

  @override
  Future<List<AuditEvent>> query(AuditQuery query) async {
    return _events
        .where((e) {
          if (query.actorId != null && e.actorId != query.actorId) {
            return false;
          }
          if (query.organizationId != null &&
              e.organizationId != query.organizationId) {
            return false;
          }
          if (query.action != null && e.action != query.action) {
            return false;
          }
          if (query.resourceType != null &&
              e.resourceType != query.resourceType) {
            return false;
          }
          if (query.resourceId != null && e.resourceId != query.resourceId) {
            return false;
          }
          if (query.from != null && e.timestamp.isBefore(query.from!)) {
            return false;
          }
          if (query.to != null && e.timestamp.isAfter(query.to!)) {
            return false;
          }
          return true;
        })
        .toList()
        .reversed
        .skip(query.offset)
        .take(query.limit)
        .toList();
  }
}
