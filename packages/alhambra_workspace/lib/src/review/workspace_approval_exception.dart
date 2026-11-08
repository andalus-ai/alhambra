/// Thrown when an approval violates policy (e.g. four-eyes rule: owner approving own workspace).
final class WorkspaceApprovalException implements Exception {
  final String message;

  const WorkspaceApprovalException(this.message);

  @override
  String toString() => 'WorkspaceApprovalException: $message';
}
