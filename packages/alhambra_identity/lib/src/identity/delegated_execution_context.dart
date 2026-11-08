import 'package:alhambra_core/alhambra_core.dart';
import 'principal.dart';

/// Context establishing delegated execution authority (e.g. human user delegating to an autonomous agent).
final class DelegatedExecutionContext {
  final Principal initiatingPrincipal;
  final Principal executingPrincipal;
  final OrganizationId organizationId;
  final String? workspaceId;
  final Map<String, Object?> delegationContext;

  const DelegatedExecutionContext({
    required this.initiatingPrincipal,
    required this.executingPrincipal,
    required this.organizationId,
    this.workspaceId,
    this.delegationContext = const {},
  });

  @override
  String toString() =>
      'DelegatedExecutionContext(initiator: $initiatingPrincipal, executor: $executingPrincipal, org: $organizationId)';
}
