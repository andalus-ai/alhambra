import 'package:alhambra_workspace/alhambra_workspace.dart';

/// Binds a specific knowledge item to a workspace.
final class KnowledgeBinding {
  final WorkspaceId workspaceId;
  final String knowledgeId;

  const KnowledgeBinding({
    required this.workspaceId,
    required this.knowledgeId,
  });

  @override
  String toString() => 'KnowledgeBinding(ws: $workspaceId -> $knowledgeId)';
}
