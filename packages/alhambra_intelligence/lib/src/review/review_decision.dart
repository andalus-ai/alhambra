/// Human review outcome decision.
enum ReviewDecision {
  approve,
  requestChanges,
  reject;

  bool get isApproved => this == ReviewDecision.approve;
  bool get isRejected => this == ReviewDecision.reject;
  bool get isChangesRequested => this == ReviewDecision.requestChanges;
}
