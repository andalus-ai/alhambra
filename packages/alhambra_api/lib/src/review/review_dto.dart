import '../common/api_request.dart';

/// Request DTO for listing or filtering review requests in the review queue.
final class ReviewQueueRequest extends ApiRequest {
  final String? status;
  final String? targetType;
  final String? workspaceId;
  final String? assigneeId;
  final int page;
  final int pageSize;

  const ReviewQueueRequest({
    this.status,
    this.targetType,
    this.workspaceId,
    this.assigneeId,
    this.page = 0,
    this.pageSize = 20,
    super.idempotencyKey,
  });
}

/// DTO representing a review request item.
final class ReviewRequestDto {
  final String id;
  final String targetType;
  final String targetId;
  final String status;
  final String? requestedBy;
  final String? assignedTo;
  final String? summary;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ReviewRequestDto({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.status,
    this.requestedBy,
    this.assignedTo,
    this.summary,
    required this.createdAt,
    this.updatedAt,
  });
}

/// Request DTO for recording a decision on a review request.
final class ReviewDecisionRequest extends ApiRequest {
  final String decision;
  final String reviewerId;
  final String? notes;

  const ReviewDecisionRequest({
    required this.decision,
    required this.reviewerId,
    this.notes,
    super.idempotencyKey,
  });
}

/// DTO representing a recorded review decision.
final class ReviewDecisionDto {
  final String id;
  final String reviewId;
  final String decision;
  final String decidedBy;
  final String? notes;
  final DateTime decidedAt;

  const ReviewDecisionDto({
    required this.id,
    required this.reviewId,
    required this.decision,
    required this.decidedBy,
    this.notes,
    required this.decidedAt,
  });
}

/// Request DTO for posting a comment on a review request.
final class CreateReviewCommentRequest extends ApiRequest {
  final String authorId;
  final String content;

  const CreateReviewCommentRequest({
    required this.authorId,
    required this.content,
    super.idempotencyKey,
  });
}

/// DTO representing a comment on a review request.
final class ReviewCommentDto {
  final String id;
  final String reviewId;
  final String authorId;
  final String content;
  final DateTime createdAt;

  const ReviewCommentDto({
    required this.id,
    required this.reviewId,
    required this.authorId,
    required this.content,
    required this.createdAt,
  });
}
