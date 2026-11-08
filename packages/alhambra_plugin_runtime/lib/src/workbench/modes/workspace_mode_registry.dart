import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'core_workspace_modes.dart';

abstract interface class WorkspaceModeRegistry {
  void register(WorkspaceMode mode);
  void unregister(String modeId);
  WorkspaceMode? get(String modeId);
  Iterable<WorkspaceMode> get all;
}

class InMemoryWorkspaceModeRegistry implements WorkspaceModeRegistry {
  final Map<String, WorkspaceMode> _modes = {};

  InMemoryWorkspaceModeRegistry({Iterable<WorkspaceMode>? initialModes}) {
    final modes = initialModes ?? CoreWorkspaceModes.defaults;
    for (final mode in modes) {
      _modes[mode.id] = mode;
    }
  }

  @override
  void register(WorkspaceMode mode) {
    _modes[mode.id] = mode;
  }

  @override
  void unregister(String modeId) {
    _modes.remove(modeId);
  }

  @override
  WorkspaceMode? get(String modeId) => _modes[modeId];

  @override
  Iterable<WorkspaceMode> get all => _modes.values;
}
