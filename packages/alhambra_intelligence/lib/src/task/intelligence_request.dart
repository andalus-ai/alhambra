import 'package:alhambra_core/alhambra_core.dart';
import 'intelligence_constraints.dart';
import 'intelligence_context.dart';
import 'intelligence_objective.dart';
import 'intelligence_scope.dart';

/// Generalized request submitted to an [IntelligenceAgent] or [IntelligenceRuntime].
final class IntelligenceRequest {
  final AnalysisId requestId;
  final WorkspaceId? workspaceId;
  final String subject;
  final IntelligenceObjective objective;
  final IntelligenceScope scope;
  final IntelligenceConstraints constraints;
  final IntelligenceContext context;
  final Map<String, Object?> parameters;

  const IntelligenceRequest({
    required this.requestId,
    this.workspaceId,
    required this.subject,
    required this.objective,
    this.scope = const IntelligenceScope(),
    this.constraints = const IntelligenceConstraints(),
    required this.context,
    this.parameters = const {},
  });

  @override
  String toString() =>
      'IntelligenceRequest($requestId: "$subject" [${objective.type}])';
}
