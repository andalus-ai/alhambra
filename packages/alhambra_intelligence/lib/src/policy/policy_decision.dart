import 'policy_violation.dart';

/// The result of evaluating an [IntelligencePolicy].
final class PolicyDecision {
  final bool allowed;
  final List<PolicyViolation> violations;

  const PolicyDecision({
    required this.allowed,
    this.violations = const [],
  });

  bool get hasViolations => violations.isNotEmpty;

  @override
  String toString() =>
      'PolicyDecision(allowed: $allowed, violations: ${violations.length})';
}
