/// Thrown when publication of a workspace is blocked by one or more [PublishGate]s.
final class WorkspacePublicationBlockedException implements Exception {
  final List<String> blockers;

  const WorkspacePublicationBlockedException(this.blockers);

  @override
  String toString() =>
      'WorkspacePublicationBlockedException: publication blocked by [${blockers.join(', ')}]';
}
