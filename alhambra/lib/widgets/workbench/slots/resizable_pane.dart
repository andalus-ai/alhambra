import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import '../../../providers/module_manager_provider.dart';

class ResizablePane extends ConsumerWidget {
  final PaneId paneId;
  final Axis axis;
  final Widget child;

  const ResizablePane({
    super.key,
    required this.paneId,
    required this.axis,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(workbenchLayoutProvider);
    final state = layout.pane(paneId);
    final size = state.size;

    return SizedBox(
      width: axis == Axis.horizontal ? size : null,
      height: axis == Axis.vertical ? size : null,
      child: child,
    );
  }
}
