import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import '../../../providers/module_manager_provider.dart';

class WorkbenchPaneSlot extends ConsumerWidget {
  final PaneId paneId;
  final Widget child;

  const WorkbenchPaneSlot({
    super.key,
    required this.paneId,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(workbenchLayoutProvider);
    final state = layout.pane(paneId);

    if (!state.visible) {
      return const SizedBox.shrink();
    }

    return child;
  }
}
