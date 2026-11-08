import 'package:alhambra_core/alhambra_core.dart';
import '../task/intelligence_request.dart';
import 'policy_decision.dart';

/// Context provided to evaluate an [IntelligencePolicy].
final class PolicyContext {
  final IntelligenceRequest request;
  final OrganizationId organizationId;
  final UserId? userId;
  final double? observedConfidence;
  final Map<String, Object?> environment;

  const PolicyContext({
    required this.request,
    required this.organizationId,
    this.userId,
    this.observedConfidence,
    this.environment = const {},
  });
}

/// Contract for governance policies constraining intelligence executions.
abstract interface class IntelligencePolicy {
  String get id;

  PolicyDecision evaluate(PolicyContext context);
}
