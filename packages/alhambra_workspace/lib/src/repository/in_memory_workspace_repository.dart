import '../model/workspace.dart';
import '../model/workspace_id.dart';
import 'workspace_repository.dart';

/// In-memory implementation of [WorkspaceRepository] for local runtimes and tests.
final class InMemoryWorkspaceRepository implements WorkspaceRepository {
  final Map<WorkspaceId, List<Workspace>> _store = {};

  @override
  Future<void> save(Workspace workspace) async {
    final list = _store.putIfAbsent(workspace.id, () => <Workspace>[]);
    list.add(workspace);
  }

  @override
  Future<Workspace?> find(WorkspaceId id) async {
    final list = _store[id];
    if (list == null || list.isEmpty) return null;
    return list.last;
  }

  @override
  Future<List<Workspace>> history(WorkspaceId id) async {
    final list = _store[id];
    if (list == null) return const [];
    return List<Workspace>.unmodifiable(list);
  }
}
