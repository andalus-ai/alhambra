/// Describes a policy rule violation.
final class PolicyViolation {
  final String policyId;
  final String rule;
  final String message;
  final String severity; // 'warning' | 'error'

  const PolicyViolation({
    required this.policyId,
    required this.rule,
    required this.message,
    this.severity = 'error',
  });

  @override
  String toString() => 'PolicyViolation($policyId [$severity]: $message)';
}
