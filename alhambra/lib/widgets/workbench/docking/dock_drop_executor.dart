import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'dock_drag_data.dart';
import 'drop_intent.dart';

class DockDropExecutor {
  final WorkbenchControllerApi workbench;

  const DockDropExecutor(this.workbench);

  void execute(DockDragData data, DropIntent intent) {
    switch (intent) {
      case NoDropIntent():
        return;

      case ReorderDropIntent():
        workbench.moveViewToGroup(
          data.viewId,
          targetGroupId: intent.targetGroupId,
          index: intent.index,
        );

      case MoveToGroupDropIntent():
        workbench.moveViewToGroup(
          data.viewId,
          targetGroupId: intent.targetGroupId,
        );

      case SplitDropIntent():
        final (direction, placement) = switch (intent.side) {
          DockSide.left => (
              SplitDirection.horizontal,
              SplitPlacement.before,
            ),
          DockSide.right => (
              SplitDirection.horizontal,
              SplitPlacement.after,
            ),
          DockSide.top => (
              SplitDirection.vertical,
              SplitPlacement.before,
            ),
          DockSide.bottom => (
              SplitDirection.vertical,
              SplitPlacement.after,
            ),
        };

        workbench.moveViewToSplit(
          data.viewId,
          targetGroupId: intent.targetGroupId,
          direction: direction,
          placement: placement,
        );
    }
  }
}
