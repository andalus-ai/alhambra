import 'package:alhambra_core/alhambra_core.dart';

/// Semantic context for an intelligence request (identity, tenancy, session).
final class IntelligenceContext {
  final OrganizationId organizationId;
  final UserId? userId;
  final WorkspaceId? workspaceId;
  final Map<String, Object?> attributes;

  const IntelligenceContext({
    required this.organizationId,
    this.userId,
    this.workspaceId,
    this.attributes = const {},
  });

  @override
  String toString() =>
      'IntelligenceContext(org: $organizationId, user: $userId, ws: $workspaceId)';
}
