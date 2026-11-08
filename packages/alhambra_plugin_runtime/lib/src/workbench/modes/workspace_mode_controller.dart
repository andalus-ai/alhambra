import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'core_workspace_modes.dart';
import 'workspace_mode_registry.dart';
import '../workbench_controller.dart';
import '../layout/pane_id.dart';

class WorkspaceModeController extends ChangeNotifier {
  final WorkspaceModeRegistry registry;
  final WorkbenchControllerApi? workbench;

  String _currentModeId;
  final _modeController = StreamController<String>.broadcast();

  WorkspaceModeController({
    required this.registry,
    this.workbench,
    String defaultModeId = CoreWorkspaceModes.ide,
  }) : _currentModeId = defaultModeId;

  String get currentModeId => _currentModeId;

  WorkspaceMode get currentMode =>
      registry.get(_currentModeId) ?? CoreWorkspaceModes.ideMode;

  Stream<String> get onModeChanged => _modeController.stream;

  void setMode(String modeId, {bool applyLayoutPreset = true}) {
    if (!registry.all.any((m) => m.id == modeId)) return;
    if (_currentModeId == modeId) return;

    _currentModeId = modeId;
    _modeController.add(_currentModeId);
    notifyListeners();

    if (applyLayoutPreset && workbench != null) {
      _applyModeLayout(modeId);
    }
  }

  void cycleNextMode() {
    final modes = registry.all.toList();
    if (modes.isEmpty) return;

    final currentIndex = modes.indexWhere((m) => m.id == _currentModeId);
    final nextIndex = (currentIndex + 1) % modes.length;
    setMode(modes[nextIndex].id);
  }

  void _applyModeLayout(String modeId) {
    final wb = workbench;
    if (wb == null) return;

    switch (modeId) {
      case CoreWorkspaceModes.vibe:
        // Vibe Coding preset:
        // Focus on chat / reasoning agent stream and diff inspection.
        wb.showPane(PaneId.sidebar);
        wb.showPane(PaneId.main);
        break;

      case CoreWorkspaceModes.ide:
        // IDE Workspace preset (VS Code style):
        // Show primary sidebar, main code editor area, bottom terminal pane, and secondary sidebar for copilot.
        wb.showPane(PaneId.sidebar);
        wb.showPane(PaneId.main);
        wb.showPane(PaneId.bottom);
        break;

      case CoreWorkspaceModes.zen:
        // Zen focus preset:
        // Maximize main editor pane, collapse peripheral panels.
        wb.hidePane(PaneId.sidebar);
        wb.hidePane(PaneId.bottom);
        wb.hidePane(PaneId.secondary);
        wb.showPane(PaneId.main);
        break;
    }
  }

  @override
  void dispose() {
    _modeController.close();
    super.dispose();
  }
}
