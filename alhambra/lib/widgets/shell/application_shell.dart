import 'package:flutter/material.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import '../../src/runtime/window/window_ui_context.dart';
import '../workbench/modes/workspace_view_host.dart';
import '../app_toolbar.dart';
import '../app_status_bar.dart';
import 'shell_region_host.dart';
import '../../theme/app_colors.dart';

class ApplicationShell extends StatelessWidget {
  final WindowUiContext? windowContext;

  const ApplicationShell({
    super.key,
    this.windowContext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: const Column(
        children: [
          // Top Region: App Toolbar
          ShellRegionHost(
            regionId: ShellRegions.top,
            child: AppToolbar(),
          ),

          // Main Center Workspace Region (Vibe or IDE workspace)
          Expanded(
            child: ShellRegionHost(
              regionId: ShellRegions.main,
              child: WorkspaceViewHost(),
            ),
          ),

          // Status Region: Bottom status bar
          ShellRegionHost(
            regionId: ShellRegions.status,
            child: AppStatusBar(),
          ),
        ],
      ),
    );
  }
}
