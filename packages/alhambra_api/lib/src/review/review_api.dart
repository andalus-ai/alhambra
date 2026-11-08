import '../common/api_page.dart';
import '../common/api_response.dart';
import 'review_dto.dart';

/// API contract for Human-In-The-Loop (HITL) review operations.
abstract interface class ReviewApi {
  /// Queries review requests in the review queue.
  Future<ApiResponse<ApiPage<ReviewRequestDto>>> queue(
    ReviewQueueRequest request,
  );

  /// Retrieves a specific review request by ID.
  Future<ApiResponse<ReviewRequestDto>> get(
    String reviewId,
  );

  /// Submits an approval, rejection, or changes-requested decision.
  Future<ApiResponse<ReviewDecisionDto>> decide(
    String reviewId,
    ReviewDecisionRequest request,
  );

  /// Adds a comment to a review request.
  Future<ApiResponse<ReviewCommentDto>> comment(
    String reviewId,
    CreateReviewCommentRequest request,
  );
}
