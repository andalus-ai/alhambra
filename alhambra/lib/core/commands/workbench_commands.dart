import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

class WorkbenchCommands {
  static void registerAll({
    required CommandRegistry commandRegistry,
    required WorkbenchControllerApi workbench,
    WorkspaceModeController? workspaceModeController,
  }) {
    commandRegistry.register(
      AppCommand(
        id: 'alhambra.workbench.splitRight',
        title: 'View: Split Editor Right',
        category: 'View',
        action: (context) {
          final activeView = workbench.layout.activeViewIn(ViewArea.main);
          if (activeView != null) {
            workbench.splitView(
              activeView,
              direction: SplitDirection.horizontal,
              placement: SplitPlacement.after,
            );
          }
        },
      ),
    );

    commandRegistry.register(
      AppCommand(
        id: 'alhambra.workbench.splitLeft',
        title: 'View: Split Editor Left',
        category: 'View',
        action: (context) {
          final activeView = workbench.layout.activeViewIn(ViewArea.main);
          if (activeView != null) {
            workbench.splitView(
              activeView,
              direction: SplitDirection.horizontal,
              placement: SplitPlacement.before,
            );
          }
        },
      ),
    );

    commandRegistry.register(
      AppCommand(
        id: 'alhambra.workbench.splitUp',
        title: 'View: Split Editor Up',
        category: 'View',
        action: (context) {
          final activeView = workbench.layout.activeViewIn(ViewArea.main);
          if (activeView != null) {
            workbench.splitView(
              activeView,
              direction: SplitDirection.vertical,
              placement: SplitPlacement.before,
            );
          }
        },
      ),
    );

    commandRegistry.register(
      AppCommand(
        id: 'alhambra.workbench.splitDown',
        title: 'View: Split Editor Down',
        category: 'View',
        action: (context) {
          final activeView = workbench.layout.activeViewIn(ViewArea.main);
          if (activeView != null) {
            workbench.splitView(
              activeView,
              direction: SplitDirection.vertical,
              placement: SplitPlacement.after,
            );
          }
        },
      ),
    );

    commandRegistry.register(
      AppCommand(
        id: 'alhambra.workbench.focusNextGroup',
        title: 'View: Focus Next Editor Group',
        category: 'View',
        action: (context) {
          workbench.focusNextGroup(area: ViewArea.main);
        },
      ),
    );

    commandRegistry.register(
      AppCommand(
        id: 'alhambra.workbench.focusPreviousGroup',
        title: 'View: Focus Previous Editor Group',
        category: 'View',
        action: (context) {
          workbench.focusPreviousGroup(area: ViewArea.main);
        },
      ),
    );

    commandRegistry.register(
      AppCommand(
        id: 'alhambra.workbench.toggleSidebar',
        title: 'View: Toggle Primary Side Bar',
        category: 'View',
        action: (context) {
          workbench.toggleSidebar();
        },
      ),
    );

    commandRegistry.register(
      AppCommand(
        id: 'alhambra.workbench.toggleBottom',
        title: 'View: Toggle Panel (Bottom)',
        category: 'View',
        action: (context) {
          workbench.toggleBottom();
        },
      ),
    );

    commandRegistry.register(
      AppCommand(
        id: 'alhambra.workbench.toggleSecondary',
        title: 'View: Toggle Secondary Side Bar',
        category: 'View',
        action: (context) {
          workbench.toggleSecondary();
        },
      ),
    );

    if (workspaceModeController != null) {
      commandRegistry.register(
        AppCommand(
          id: 'alhambra.mode.vibe',
          title: 'View: Switch to Vibe Coding Mode',
          category: 'View',
          action: (context) {
            workspaceModeController.setMode(CoreWorkspaceModes.vibe);
          },
        ),
      );

      commandRegistry.register(
        AppCommand(
          id: 'alhambra.mode.ide',
          title: 'View: Switch to IDE Workspace Mode',
          category: 'View',
          action: (context) {
            workspaceModeController.setMode(CoreWorkspaceModes.ide);
          },
        ),
      );

      commandRegistry.register(
        AppCommand(
          id: 'alhambra.mode.zen',
          title: 'View: Switch to Zen Focus Mode',
          category: 'View',
          action: (context) {
            workspaceModeController.setMode(CoreWorkspaceModes.zen);
          },
        ),
      );

      commandRegistry.register(
        AppCommand(
          id: 'alhambra.mode.cycle',
          title: 'View: Cycle Workspace Layout Modes',
          category: 'View',
          action: (context) {
            workspaceModeController.cycleNextMode();
          },
        ),
      );
    }
  }
}
