import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import '../../../providers/module_manager_provider.dart';
import '../workbench_area.dart';
import 'workbench_splitter.dart';

class BottomPaneSlot extends ConsumerWidget {
  const BottomPaneSlot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(workbenchLayoutProvider);
    final controller = ref.watch(workbenchControllerProvider);
    final paneState = layout.pane(PaneId.bottom);

    if (!paneState.visible) {
      return const SizedBox.shrink();
    }

    final height = paneState.size ?? 240.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        WorkbenchSplitter(
          axis: SplitterAxis.vertical,
          onDrag: (delta) {
            controller.resizeBottom(height - delta);
          },
          onDoubleClick: () {
            controller.toggleBottom();
          },
        ),
        SizedBox(
          height: height,
          width: double.infinity,
          child: const WorkbenchArea(
            area: ViewArea.bottomPanel,
          ),
        ),
      ],
    );
  }
}
