import 'package:alhambra_core/alhambra_core.dart';

import 'review_decision.dart';

/// Recorded review evaluation on a workspace.
final class WorkspaceReview {
  final WorkspaceId workspaceId;
  final UserId reviewerId;
  final ReviewDecision decision;
  final String? comment;
  final DateTime createdAt;

  const WorkspaceReview({
    required this.workspaceId,
    required this.reviewerId,
    required this.decision,
    this.comment,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkspaceReview &&
          runtimeType == other.runtimeType &&
          workspaceId == other.workspaceId &&
          reviewerId == other.reviewerId &&
          decision == other.decision &&
          comment == other.comment &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
        workspaceId,
        reviewerId,
        decision,
        comment,
        createdAt,
      );

  @override
  String toString() =>
      'WorkspaceReview(workspace: $workspaceId, reviewer: $reviewerId, decision: $decision)';
}
