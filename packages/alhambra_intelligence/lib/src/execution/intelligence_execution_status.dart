/// Lifecycle status of an intelligence execution.
enum IntelligenceExecutionStatus {
  pending,
  running,
  waitingForReview,
  completed,
  failed,
  cancelled;

  bool get isTerminal =>
      this == IntelligenceExecutionStatus.completed ||
      this == IntelligenceExecutionStatus.failed ||
      this == IntelligenceExecutionStatus.cancelled;

  bool get isWaitingForReview =>
      this == IntelligenceExecutionStatus.waitingForReview;
}
