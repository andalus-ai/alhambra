import 'package:alhambra_core/alhambra_core.dart';

/// Request for human-in-the-loop review to approve or reject a step / execution.
final class ReviewRequest {
  final ExecutionId executionId;
  final String subject;
  final String reason;
  final String? stepId;
  final Map<String, Object?> contextData;

  const ReviewRequest({
    required this.executionId,
    required this.subject,
    required this.reason,
    this.stepId,
    this.contextData = const {},
  });

  @override
  String toString() =>
      'ReviewRequest($executionId: "$subject", reason: "$reason")';
}
