import 'dart:async';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

/// Default workspace manager handling multi-workspace lifecycle and scoped service isolation.
class DefaultWorkspaceManager implements WorkspaceManager {
  final Map<String, WorkspaceServices> _workspaces = {};
  String? _activeWorkspaceId;
  int _counter = 0;

  @override
  List<String> get workspaceIds => _workspaces.keys.toList(growable: false);

  @override
  String? get activeWorkspaceId => _activeWorkspaceId;

  @override
  WorkspaceServices get(String workspaceId) {
    final ws = _workspaces[workspaceId];
    if (ws == null) {
      throw ArgumentError('Workspace $workspaceId not found');
    }
    return ws;
  }

  @override
  Future<String> createWorkspace() async {
    final id = 'workspace_${DateTime.now().microsecondsSinceEpoch}_${++_counter}';
    final ws = WorkspaceServices(workspaceId: id);
    _workspaces[id] = ws;
    _activeWorkspaceId ??= id;
    return id;
  }

  @override
  Future<void> activateWorkspace(String workspaceId) async {
    if (!_workspaces.containsKey(workspaceId)) {
      throw ArgumentError('Workspace $workspaceId does not exist');
    }
    _activeWorkspaceId = workspaceId;
  }

  @override
  Future<void> closeWorkspace(String workspaceId) async {
    final ws = _workspaces.remove(workspaceId);
    if (ws != null) {
      await ws.dispose();
    }
    if (_activeWorkspaceId == workspaceId) {
      _activeWorkspaceId = _workspaces.keys.firstOrNull;
    }
  }

  @override
  Future<void> dispose() async {
    for (final ws in _workspaces.values) {
      await ws.dispose();
    }
    _workspaces.clear();
    _activeWorkspaceId = null;
  }
}

/// Composition root building standard application services per edition profile.
class ApplicationBuilder {
  final ApplicationProfile profile;

  const ApplicationBuilder({
    this.profile = const ApplicationProfile(edition: ProductEdition.community),
  });

  WorkspaceManager buildWorkspaceManager() {
    return DefaultWorkspaceManager();
  }

  AlhambraUIContext buildUIContext({
    WorkspaceManager? workspaceManager,
  }) {
    return AlhambraUIContext(
      profile: profile,
      workspaceManager: workspaceManager ?? buildWorkspaceManager(),
    );
  }
}
