import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

void main() {
  group('Workspace Mode Abstraction and Controller Tests', () {
    test('WorkspaceModeRegistry has standard default modes and supports custom registration', () {
      final registry = InMemoryWorkspaceModeRegistry();

      expect(registry.get(CoreWorkspaceModes.vibe), isNotNull);
      expect(registry.get(CoreWorkspaceModes.ide), isNotNull);
      expect(registry.get(CoreWorkspaceModes.zen), isNotNull);

      // Register custom mode
      const customMode = WorkspaceMode(
        id: 'swarm.cockpit',
        title: 'Swarm Cockpit',
        description: 'Multi-agent orchestration view',
        icon: Icons.hub,
        isCustom: true,
      );

      registry.register(customMode);
      expect(registry.get('swarm.cockpit'), isNotNull);
      expect(registry.get('swarm.cockpit')?.isCustom, isTrue);

      registry.unregister('swarm.cockpit');
      expect(registry.get('swarm.cockpit'), isNull);
    });

    test(
      'WorkspaceModeController switches modes and updates workbench layout',
      () {
        final views = ViewRegistry();
        final workbench = WorkbenchController(views: views);
        final registry = InMemoryWorkspaceModeRegistry();
        final controller = WorkspaceModeController(
          registry: registry,
          workbench: workbench,
          defaultModeId: CoreWorkspaceModes.ide,
        );

        expect(controller.currentModeId, CoreWorkspaceModes.ide);
        expect(controller.currentMode.title, 'IDE Workspace');

        // Switch to Vibe mode
        controller.setMode(CoreWorkspaceModes.vibe);
        expect(controller.currentModeId, CoreWorkspaceModes.vibe);
        expect(controller.currentMode.title, 'Vibe Coding');

        // Switch to Zen mode -> collapses sidebars
        controller.setMode(CoreWorkspaceModes.zen);
        expect(controller.currentModeId, CoreWorkspaceModes.zen);
        expect(workbench.layout.pane(PaneId.sidebar).visible, isFalse);
        expect(workbench.layout.pane(PaneId.bottom).visible, isFalse);

        // Cycle mode back
        controller.cycleNextMode();
        expect(controller.currentModeId, CoreWorkspaceModes.vibe);
      },
    );
  });
}
