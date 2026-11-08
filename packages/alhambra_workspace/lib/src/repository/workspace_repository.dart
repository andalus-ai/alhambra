import '../model/workspace.dart';
import '../model/workspace_id.dart';

/// Persistence abstraction for [Workspace] entities and their version histories.
abstract interface class WorkspaceRepository {
  /// Persists a new snapshot/version of a workspace.
  Future<void> save(Workspace workspace);

  /// Retrieves the latest state of the workspace with the given [id], or `null` if not found.
  Future<Workspace?> find(WorkspaceId id);

  /// Retrieves the chronological history of versions for [id].
  Future<List<Workspace>> history(WorkspaceId id);
}
