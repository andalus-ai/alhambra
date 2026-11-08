import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import '../../../providers/module_manager_provider.dart';
import '../workbench_area.dart';
import '../../sidebar/sidebar_widget.dart';
import 'workbench_splitter.dart';

class SidePaneSlot extends ConsumerWidget {
  const SidePaneSlot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(workbenchLayoutProvider);
    final controller = ref.watch(workbenchControllerProvider);
    final paneState = layout.pane(PaneId.sidebar);

    if (!paneState.visible) {
      return const SizedBox.shrink();
    }

    final width = paneState.size ?? 280.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: width,
          child: const WorkbenchArea(
            area: ViewArea.sidebar,
            fallback: SidebarWidget(),
          ),
        ),
        WorkbenchSplitter(
          axis: SplitterAxis.horizontal,
          onDrag: (delta) {
            controller.resizeSidebar(width + delta);
          },
          onDoubleClick: () {
            controller.toggleSidebar();
          },
        ),
      ],
    );
  }
}
