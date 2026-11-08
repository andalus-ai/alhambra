import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'pane_id.dart';

abstract interface class WorkbenchLayoutPolicy {
  bool canMoveView(String viewId, ViewArea destination);
  bool canResizePane(PaneId pane);
  bool canHidePane(PaneId pane);
  bool canCollapsePane(PaneId pane);
  bool canSplitView(String viewId);
  bool canSplitGroup(String groupId);
  bool canResizeSplit(String splitNodeId);
  bool canCloseGroup(String groupId);
  bool canDockViewToGroup(String viewId, String targetGroupId);
  bool canSplitViewAtGroup(String viewId, String targetGroupId);
}

class DefaultWorkbenchLayoutPolicy implements WorkbenchLayoutPolicy {
  const DefaultWorkbenchLayoutPolicy();

  @override
  bool canMoveView(String viewId, ViewArea destination) => true;

  @override
  bool canResizePane(PaneId pane) => pane != PaneId.main;

  @override
  bool canHidePane(PaneId pane) => pane != PaneId.main;

  @override
  bool canCollapsePane(PaneId pane) => pane != PaneId.main;

  @override
  bool canSplitView(String viewId) => true;

  @override
  bool canSplitGroup(String groupId) => true;

  @override
  bool canResizeSplit(String splitNodeId) => true;

  @override
  bool canCloseGroup(String groupId) => true;

  @override
  bool canDockViewToGroup(String viewId, String targetGroupId) => true;

  @override
  bool canSplitViewAtGroup(String viewId, String targetGroupId) => true;
}

class LockedEnterpriseLayoutPolicy implements WorkbenchLayoutPolicy {
  const LockedEnterpriseLayoutPolicy();

  @override
  bool canMoveView(String viewId, ViewArea destination) => false;

  @override
  bool canResizePane(PaneId pane) => false;

  @override
  bool canHidePane(PaneId pane) => pane == PaneId.bottom;

  @override
  bool canCollapsePane(PaneId pane) => false;

  @override
  bool canSplitView(String viewId) => false;

  @override
  bool canSplitGroup(String groupId) => false;

  @override
  bool canResizeSplit(String splitNodeId) => false;

  @override
  bool canCloseGroup(String groupId) => false;

  @override
  bool canDockViewToGroup(String viewId, String targetGroupId) => false;

  @override
  bool canSplitViewAtGroup(String viewId, String targetGroupId) => false;
}
