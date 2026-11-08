import 'pane_id.dart';
import 'pane_state.dart';

class WorkbenchPane {
  final PaneId id;
  final double defaultSize;
  final double minSize;
  final double? maxSize;
  final bool resizable;
  final bool collapsible;
  final PaneBehavior behavior;

  const WorkbenchPane({
    required this.id,
    required this.defaultSize,
    required this.minSize,
    this.maxSize,
    this.resizable = true,
    this.collapsible = true,
    this.behavior = const PaneBehavior(),
  });
}

abstract final class CoreWorkbenchPanes {
  static const sidebar = WorkbenchPane(
    id: PaneId.sidebar,
    defaultSize: 280,
    minSize: 180,
    maxSize: 600,
  );

  static const main = WorkbenchPane(
    id: PaneId.main,
    defaultSize: 0,
    minSize: 0,
    resizable: false,
    collapsible: false,
  );

  static const bottom = WorkbenchPane(
    id: PaneId.bottom,
    defaultSize: 240,
    minSize: 100,
    maxSize: 600,
    behavior: PaneBehavior(hideWhenEmpty: true),
  );

  static const secondary = WorkbenchPane(
    id: PaneId.secondary,
    defaultSize: 300,
    minSize: 180,
    maxSize: 700,
    behavior: PaneBehavior(hideWhenEmpty: true),
  );

  static const Map<PaneId, WorkbenchPane> defaults = {
    PaneId.sidebar: sidebar,
    PaneId.main: main,
    PaneId.bottom: bottom,
    PaneId.secondary: secondary,
  };
}
