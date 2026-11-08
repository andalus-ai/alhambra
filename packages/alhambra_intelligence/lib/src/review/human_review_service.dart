import 'package:alhambra_core/alhambra_core.dart';
import 'review_decision.dart';
import 'review_request.dart';

/// Result of evaluating or recording a human review decision.
final class ReviewDecisionResult {
  final ExecutionId executionId;
  final ReviewDecision decision;
  final String? reviewerComment;
  final UserId? reviewerId;
  final DateTime decidedAt;

  const ReviewDecisionResult({
    required this.executionId,
    required this.decision,
    this.reviewerComment,
    this.reviewerId,
    required this.decidedAt,
  });

  @override
  String toString() =>
      'ReviewDecisionResult($executionId: ${decision.name} by $reviewerId)';
}

/// Service contract for managing pending human-in-the-loop review requests.
abstract interface class HumanReviewService {
  Future<void> submitRequest(ReviewRequest request);

  Future<List<ReviewRequest>> getPendingRequests({String? executionId});

  Future<ReviewDecisionResult> decide({
    required ReviewRequest request,
    required ReviewDecision decision,
    String? comment,
    UserId? reviewerId,
  });
}

/// In-memory implementation of [HumanReviewService] for tests and local execution.
final class InMemoryHumanReviewService implements HumanReviewService {
  final List<ReviewRequest> _pending = [];
  final List<ReviewDecisionResult> _decisions = [];

  @override
  Future<void> submitRequest(ReviewRequest request) async {
    _pending.add(request);
  }

  @override
  Future<List<ReviewRequest>> getPendingRequests({String? executionId}) async {
    if (executionId == null) return List.unmodifiable(_pending);
    return _pending.where((r) => r.executionId.value == executionId).toList();
  }

  @override
  Future<ReviewDecisionResult> decide({
    required ReviewRequest request,
    required ReviewDecision decision,
    String? comment,
    UserId? reviewerId,
  }) async {
    _pending.removeWhere((r) => r.executionId == request.executionId);
    final result = ReviewDecisionResult(
      executionId: request.executionId,
      decision: decision,
      reviewerComment: comment,
      reviewerId: reviewerId,
      decidedAt: DateTime.now(),
    );
    _decisions.add(result);
    return result;
  }
}
