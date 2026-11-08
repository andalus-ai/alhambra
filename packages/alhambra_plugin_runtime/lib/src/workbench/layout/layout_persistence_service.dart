import '../workbench_layout_state.dart';

abstract interface class LayoutPersistenceService {
  Future<void> saveLayout(String workspaceId, WorkbenchLayoutState layout);
  Future<WorkbenchLayoutState?> loadLayout(String workspaceId);
  Future<void> resetLayout(String workspaceId);
  void scheduleSave(WorkbenchLayoutState layout, {String workspaceId = 'default'});
}

class InMemoryLayoutPersistenceService implements LayoutPersistenceService {
  final Map<String, WorkbenchLayoutState> _storage = {};

  @override
  Future<void> saveLayout(String workspaceId, WorkbenchLayoutState layout) async {
    _storage[workspaceId] = layout;
  }

  @override
  Future<WorkbenchLayoutState?> loadLayout(String workspaceId) async {
    return _storage[workspaceId];
  }

  @override
  Future<void> resetLayout(String workspaceId) async {
    _storage.remove(workspaceId);
  }

  @override
  void scheduleSave(WorkbenchLayoutState layout, {String workspaceId = 'default'}) {
    saveLayout(workspaceId, layout);
  }
}
