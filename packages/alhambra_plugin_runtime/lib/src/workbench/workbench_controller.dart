import 'dart:async';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import '../views/view_registry.dart';
import 'layout/layout_persistence_service.dart';
import 'layout/pane_id.dart';
import 'layout/pane_state.dart';
import 'layout/tree/layout_node.dart';
import 'layout/tree/layout_tree_editor.dart';
import 'layout/tree/layout_tree_navigator.dart';
import 'layout/tree/split_direction.dart';
import 'layout/tree/workbench_layout_validator.dart';
import 'layout/view_group_id.dart';
import 'layout/view_group_state.dart';
import 'layout/workbench_group_resolver.dart';
import 'layout/workbench_layout_policy.dart';
import 'layout/workbench_pane.dart';
import 'view_location.dart';
import 'workbench_layout_resolver.dart';
import 'workbench_layout_state.dart';

abstract interface class WorkbenchControllerApi {
  WorkbenchLayoutState get layout;
  String? get activeActivityId;
  WorkbenchPanelDimensions get dimensions;

  // Pane operations
  void showPane(PaneId pane);
  void hidePane(PaneId pane);
  void togglePane(PaneId pane, {bool? visible});
  void collapsePane(PaneId pane);
  void expandPane(PaneId pane);
  void resizePane(PaneId pane, double size);

  void resizeSidebar(double width);
  void resizeSecondary(double width);
  void resizeBottom(double height);
  void toggleSidebar({bool? visible});
  void toggleSecondary({bool? visible});
  void toggleBottom({bool? visible});

  // Activity bar
  void activateActivity(String activityId, {String? defaultViewId});

  // View & Group operations
  void openView(String viewId, {ViewArea? area, String? groupId});
  void closeView(String viewId);
  void activateView(String viewId);
  void moveView(String viewId, ViewArea destination);
  void moveViewToGroup(
    String viewId, {
    required String targetGroupId,
    int? index,
  });
  void reorderViewInGroup(String groupId, int oldIndex, int newIndex);
  void focusGroup(String groupId);
  void focusNextGroup({ViewArea area = ViewArea.main});
  void focusPreviousGroup({ViewArea area = ViewArea.main});

  // Split operations
  void splitViewGroup(
    String groupId, {
    required SplitDirection direction,
    required SplitPlacement placement,
    double ratio,
  });

  void splitView(
    String viewId, {
    required SplitDirection direction,
    required SplitPlacement placement,
    double ratio,
  });

  void moveViewToSplit(
    String viewId, {
    required String targetGroupId,
    required SplitDirection direction,
    required SplitPlacement placement,
    double ratio,
  });

  void closeSplit(String splitNodeId);

  void beginSplitResize(String splitNodeId);
  void resizeSplit(String splitNodeId, double ratio);
  void endSplitResize(String splitNodeId);
}

class WorkbenchController implements WorkbenchControllerApi {
  final ViewRegistry views;
  final WorkbenchLayoutResolver layoutResolver;
  final WorkbenchGroupResolver groupResolver;
  final ViewGroupIdGenerator groupIdGenerator;
  final LayoutTreeEditor treeEditor;
  final LayoutTreeNavigator treeNavigator;
  final WorkbenchLayoutValidator layoutValidator;
  final WorkbenchLayoutPolicy layoutPolicy;
  final LayoutPersistenceService layoutPersistence;

  final Map<PaneId, WorkbenchPane> paneDefinitions;
  final StreamController<WorkbenchLayoutState> _stateController =
      StreamController<WorkbenchLayoutState>.broadcast();

  WorkbenchLayoutState _state = WorkbenchLayoutState.defaults();
  String? _activeSplitResizeId;

  WorkbenchController({
    required this.views,
    WorkbenchLayoutResolver? layoutResolver,
    WorkbenchGroupResolver? groupResolver,
    ViewGroupIdGenerator? groupIdGenerator,
    LayoutTreeEditor? treeEditor,
    LayoutTreeNavigator? treeNavigator,
    WorkbenchLayoutValidator? layoutValidator,
    WorkbenchLayoutPolicy? layoutPolicy,
    LayoutPersistenceService? layoutPersistence,
    Map<PaneId, WorkbenchPane>? paneDefinitions,
    WorkbenchPanelDimensions? initialDimensions,
  }) : layoutResolver = layoutResolver ?? WorkbenchLayoutResolver(views: views),
       groupResolver = groupResolver ?? const WorkbenchGroupResolver(),
       groupIdGenerator = groupIdGenerator ?? RuntimeViewGroupIdGenerator(),
       treeEditor = treeEditor ?? const LayoutTreeEditor(),
       treeNavigator = treeNavigator ?? const LayoutTreeNavigator(),
       layoutValidator = layoutValidator ?? const WorkbenchLayoutValidator(),
       layoutPolicy = layoutPolicy ?? const DefaultWorkbenchLayoutPolicy(),
       layoutPersistence =
           layoutPersistence ?? InMemoryLayoutPersistenceService(),
       paneDefinitions = paneDefinitions ?? CoreWorkbenchPanes.defaults {
    if (initialDimensions != null) {
      _state = _state.copyWith(dimensions: initialDimensions);
    }
  }

  @override
  WorkbenchLayoutState get layout => _state;

  @override
  String? get activeActivityId => _state.activeActivityId;

  @override
  WorkbenchPanelDimensions get dimensions => _state.dimensions;

  Stream<WorkbenchLayoutState> get onLayoutChanged => _stateController.stream;

  void _notify() {
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }

  void _commitLayoutChange({bool persist = true}) {
    assert(() {
      layoutValidator.validate(
        panes: _state.panes,
        locations: _state.locations,
        groups: _state.groups,
        areaLayouts: _state.areaLayouts,
      );
      return true;
    }());

    _notify();

    if (persist) {
      layoutPersistence.scheduleSave(_state);
    }
  }

  PaneId _paneForArea(ViewArea area) {
    return switch (area) {
      ViewArea.sidebar => PaneId.sidebar,
      ViewArea.main => PaneId.main,
      ViewArea.bottomPanel => PaneId.bottom,
      ViewArea.secondaryPanel => PaneId.secondary,
    };
  }

  void _showPaneForArea(ViewArea area) {
    final paneId = _paneForArea(area);
    if (paneId != PaneId.main) {
      showPane(paneId);
    }
  }

  // --- Pane Operations ---

  @override
  void showPane(PaneId pane) {
    if (!layoutPolicy.canHidePane(pane) && pane == PaneId.main) return;
    final current = _state.pane(pane);
    if (current.visible && !current.collapsed) return;

    final def = paneDefinitions[pane];
    final size = current.size ?? def?.defaultSize;

    _state = _state.copyWith(
      panes: {
        ..._state.panes,
        pane: current.copyWith(visible: true, collapsed: false, size: size),
      },
    );
    _commitLayoutChange();
  }

  @override
  void hidePane(PaneId pane) {
    if (!layoutPolicy.canHidePane(pane)) return;
    final current = _state.pane(pane);
    if (!current.visible) return;

    _state = _state.copyWith(
      panes: {..._state.panes, pane: current.copyWith(visible: false)},
    );
    _commitLayoutChange();
  }

  @override
  void togglePane(PaneId pane, {bool? visible}) {
    final current = _state.pane(pane);
    final nextVisible = visible ?? !current.visible;
    if (nextVisible) {
      showPane(pane);
    } else {
      hidePane(pane);
    }
  }

  @override
  void collapsePane(PaneId pane) {
    if (!layoutPolicy.canCollapsePane(pane)) return;
    final current = _state.pane(pane);
    _state = _state.copyWith(
      panes: {..._state.panes, pane: current.copyWith(collapsed: true)},
    );
    _commitLayoutChange();
  }

  @override
  void expandPane(PaneId pane) {
    final current = _state.pane(pane);
    _state = _state.copyWith(
      panes: {..._state.panes, pane: current.copyWith(collapsed: false)},
    );
    _commitLayoutChange();
  }

  @override
  void resizePane(PaneId pane, double size) {
    if (!layoutPolicy.canResizePane(pane)) return;
    final def = paneDefinitions[pane];
    if (def == null || !def.resizable) return;

    var resolved = size;
    if (resolved < def.minSize) resolved = def.minSize;
    if (def.maxSize != null && resolved > def.maxSize!) resolved = def.maxSize!;

    final current = _state.pane(pane);
    _state = _state.copyWith(
      panes: {
        ..._state.panes,
        pane: current.copyWith(size: resolved),
      },
    );
    _commitLayoutChange();
  }

  @override
  void resizeSidebar(double width) => resizePane(PaneId.sidebar, width);

  @override
  void resizeSecondary(double width) => resizePane(PaneId.secondary, width);

  @override
  void resizeBottom(double height) => resizePane(PaneId.bottom, height);

  @override
  void toggleSidebar({bool? visible}) =>
      togglePane(PaneId.sidebar, visible: visible);

  @override
  void toggleSecondary({bool? visible}) =>
      togglePane(PaneId.secondary, visible: visible);

  @override
  void toggleBottom({bool? visible}) =>
      togglePane(PaneId.bottom, visible: visible);

  // --- Activity Bar ---

  @override
  void activateActivity(String activityId, {String? defaultViewId}) {
    final isSameActivity = _state.activeActivityId == activityId;
    if (isSameActivity && _state.pane(PaneId.sidebar).visible) {
      toggleSidebar(visible: false);
      return;
    }

    _state = _state.copyWith(activeActivityId: activityId);
    showPane(PaneId.sidebar);

    if (defaultViewId != null) {
      openView(defaultViewId);
    } else {
      _commitLayoutChange();
    }
  }

  // --- View & Group Operations ---

  @override
  void openView(String viewId, {ViewArea? area, String? groupId}) {
    final existing = _state.locations[viewId];
    if (existing != null) {
      activateView(viewId);
      return;
    }

    final initialLocation = layoutResolver.resolveInitialLocation(viewId);
    final targetArea = area ?? initialLocation.area;

    final targetGroupId =
        groupId ??
        (area == null || area == initialLocation.area
            ? initialLocation.groupId
            : null) ??
        _state.activeGroupIds[targetArea] ??
        groupResolver.defaultGroupFor(targetArea);

    var group = _state.group(targetGroupId);
    var nextGroups = Map<String, ViewGroupState>.from(_state.groups);
    var nextAreaLayouts = Map<ViewArea, LayoutNode>.from(_state.areaLayouts);

    if (group == null) {
      // Create new group if missing
      group = ViewGroupState(
        id: targetGroupId,
        area: targetArea,
        viewIds: [viewId],
        activeViewId: viewId,
      );
      nextGroups[targetGroupId] = group;
      nextAreaLayouts[targetArea] = ViewGroupNode(
        id: 'node.$targetGroupId',
        groupId: targetGroupId,
      );
    } else {
      final updatedViewIds = [...group.viewIds, viewId];
      nextGroups[targetGroupId] = group.copyWith(
        viewIds: updatedViewIds,
        activeViewId: viewId,
      );
    }

    final nextLocations = Map<String, ViewLocation>.from(_state.locations);
    nextLocations[viewId] = ViewLocation(
      viewId: viewId,
      area: group.area,
      groupId: group.id,
    );

    final nextActiveGroups = Map<ViewArea, String?>.from(_state.activeGroupIds);
    nextActiveGroups[group.area] = group.id;

    _state = _state.copyWith(
      locations: nextLocations,
      groups: nextGroups,
      areaLayouts: nextAreaLayouts,
      activeGroupIds: nextActiveGroups,
    );

    _showPaneForArea(group.area);
    _commitLayoutChange();
  }

  @override
  void closeView(String viewId) {
    final location = _state.locations[viewId];
    if (location == null) return;

    final group = _state.group(location.groupId ?? '');
    if (group == null) return;

    final nextViewIds = List<String>.from(group.viewIds)..remove(viewId);
    String? nextActiveId = group.activeViewId;
    if (nextActiveId == viewId) {
      nextActiveId = nextViewIds.isNotEmpty ? nextViewIds.last : null;
    }

    final nextLocations = Map<String, ViewLocation>.from(_state.locations)
      ..remove(viewId);
    final nextGroups = Map<String, ViewGroupState>.from(_state.groups);

    nextGroups[group.id] = group.copyWith(
      viewIds: nextViewIds,
      activeViewId: nextActiveId,
    );

    _state = _state.copyWith(locations: nextLocations, groups: nextGroups);

    // If all views in area closed, check behavior hideWhenEmpty
    final allViewsInArea = _state.viewsIn(group.area);
    if (allViewsInArea.isEmpty) {
      final paneId = _paneForArea(group.area);
      final def = paneDefinitions[paneId];
      if (def?.behavior.hideWhenEmpty == true) {
        hidePane(paneId);
      }
    }

    _commitLayoutChange();
  }

  @override
  void activateView(String viewId) {
    final location = _state.locations[viewId];
    if (location == null) {
      openView(viewId);
      return;
    }

    final group = _state.group(location.groupId ?? '');
    if (group == null) return;

    final nextGroups = Map<String, ViewGroupState>.from(_state.groups);
    nextGroups[group.id] = group.copyWith(activeViewId: viewId);

    final nextActiveGroups = Map<ViewArea, String?>.from(_state.activeGroupIds);
    nextActiveGroups[group.area] = group.id;

    _state = _state.copyWith(
      groups: nextGroups,
      activeGroupIds: nextActiveGroups,
    );

    _showPaneForArea(group.area);
    _commitLayoutChange();
  }

  @override
  void moveView(String viewId, ViewArea destination) {
    final view = views.get(viewId);
    if (view != null && !view.behavior.movable) return;
    if (!layoutPolicy.canMoveView(viewId, destination)) return;

    final current = _state.locations[viewId];
    if (current == null || current.area == destination) return;

    closeView(viewId);
    openView(viewId, area: destination);
  }

  @override
  void moveViewToGroup(
    String viewId, {
    required String targetGroupId,
    int? index,
  }) {
    final targetGroup = _state.group(targetGroupId);
    if (targetGroup == null) return;

    final view = views.get(viewId);
    if (view != null && !view.behavior.movable) return;
    if (!layoutPolicy.canDockViewToGroup(viewId, targetGroupId)) return;

    final location = _state.locations[viewId];
    if (location == null) {
      openView(viewId, groupId: targetGroupId);
      return;
    }

    final sourceGroup = _state.group(location.groupId ?? '');
    if (sourceGroup == null) return;

    final nextGroups = Map<String, ViewGroupState>.from(_state.groups);
    final nextLocations = Map<String, ViewLocation>.from(_state.locations);

    if (sourceGroup.id == targetGroupId) {
      // Reordering within the same group
      final viewsList = List<String>.from(sourceGroup.viewIds);
      viewsList.remove(viewId);
      final insertIdx = (index ?? viewsList.length).clamp(0, viewsList.length);
      viewsList.insert(insertIdx, viewId);

      nextGroups[sourceGroup.id] = sourceGroup.copyWith(
        viewIds: viewsList,
        activeViewId: viewId,
      );
    } else {
      // Moving across different groups
      final sourceViews = List<String>.from(sourceGroup.viewIds)
        ..remove(viewId);
      String? sourceActive = sourceGroup.activeViewId;
      if (sourceActive == viewId) {
        sourceActive = sourceViews.isNotEmpty ? sourceViews.last : null;
      }
      nextGroups[sourceGroup.id] = sourceGroup.copyWith(
        viewIds: sourceViews,
        activeViewId: sourceActive,
      );

      final targetViews = List<String>.from(targetGroup.viewIds);
      final insertIdx = (index ?? targetViews.length).clamp(
        0,
        targetViews.length,
      );
      targetViews.insert(insertIdx, viewId);
      nextGroups[targetGroup.id] = targetGroup.copyWith(
        viewIds: targetViews,
        activeViewId: viewId,
      );

      nextLocations[viewId] = ViewLocation(
        viewId: viewId,
        area: targetGroup.area,
        groupId: targetGroup.id,
      );
    }

    final nextActiveGroups = Map<ViewArea, String?>.from(_state.activeGroupIds);
    nextActiveGroups[targetGroup.area] = targetGroup.id;

    _state = _state.copyWith(
      locations: nextLocations,
      groups: nextGroups,
      activeGroupIds: nextActiveGroups,
    );

    _showPaneForArea(targetGroup.area);
    _commitLayoutChange();
  }

  @override
  void reorderViewInGroup(String groupId, int oldIndex, int newIndex) {
    final group = _state.group(groupId);
    if (group == null) return;

    final viewsList = List<String>.from(group.viewIds);
    if (oldIndex < 0 || oldIndex >= viewsList.length) return;

    final viewId = viewsList.removeAt(oldIndex);
    final targetIndex = newIndex.clamp(0, viewsList.length);
    viewsList.insert(targetIndex, viewId);

    final nextGroups = Map<String, ViewGroupState>.from(_state.groups);
    nextGroups[groupId] = group.copyWith(viewIds: viewsList);

    _state = _state.copyWith(groups: nextGroups);
    _commitLayoutChange();
  }

  @override
  void focusGroup(String groupId) {
    final group = _state.group(groupId);
    if (group == null) return;

    final nextActiveGroups = Map<ViewArea, String?>.from(_state.activeGroupIds);
    nextActiveGroups[group.area] = group.id;

    _state = _state.copyWith(activeGroupIds: nextActiveGroups);
    _commitLayoutChange(persist: false);
  }

  @override
  void focusNextGroup({ViewArea area = ViewArea.main}) {
    final root = _state.layoutFor(area);
    if (root == null) return;

    final groupIds = treeNavigator.collectGroupIds(root);
    if (groupIds.length <= 1) return;

    final current = _state.activeGroupIds[area];
    final currentIndex = current != null ? groupIds.indexOf(current) : 0;
    final nextIndex = (currentIndex + 1) % groupIds.length;

    focusGroup(groupIds[nextIndex]);
  }

  @override
  void focusPreviousGroup({ViewArea area = ViewArea.main}) {
    final root = _state.layoutFor(area);
    if (root == null) return;

    final groupIds = treeNavigator.collectGroupIds(root);
    if (groupIds.length <= 1) return;

    final current = _state.activeGroupIds[area];
    final currentIndex = current != null ? groupIds.indexOf(current) : 0;
    final prevIndex = (currentIndex - 1 + groupIds.length) % groupIds.length;

    focusGroup(groupIds[prevIndex]);
  }

  // --- Split Operations ---

  @override
  void splitViewGroup(
    String groupId, {
    required SplitDirection direction,
    required SplitPlacement placement,
    double ratio = 0.5,
  }) {
    final group = _state.group(groupId);
    if (group == null) return;
    if (!layoutPolicy.canSplitGroup(groupId)) return;

    final root = _state.layoutFor(group.area);
    if (root == null) return;

    final newGroupId = groupIdGenerator.next();
    final newGroup = ViewGroupState(
      id: newGroupId,
      area: group.area,
      viewIds: [],
      activeViewId: null,
    );

    final updatedTree = treeEditor.splitGroup(
      root,
      groupId: groupId,
      newGroupId: newGroupId,
      direction: direction,
      placement: placement,
      ratio: ratio,
    );

    final nextGroups = Map<String, ViewGroupState>.from(_state.groups)
      ..[newGroupId] = newGroup;

    final nextAreaLayouts = Map<ViewArea, LayoutNode>.from(_state.areaLayouts)
      ..[group.area] = updatedTree;

    final nextActiveGroups = Map<ViewArea, String?>.from(_state.activeGroupIds)
      ..[group.area] = newGroupId;

    _state = _state.copyWith(
      groups: nextGroups,
      areaLayouts: nextAreaLayouts,
      activeGroupIds: nextActiveGroups,
    );

    _commitLayoutChange();
  }

  @override
  void splitView(
    String viewId, {
    required SplitDirection direction,
    required SplitPlacement placement,
    double ratio = 0.5,
  }) {
    final location = _state.locations[viewId];
    if (location == null || location.groupId == null) return;

    final view = views.get(viewId);
    if (view != null && !view.behavior.supportsSplit) return;
    if (!layoutPolicy.canSplitView(viewId)) return;

    moveViewToSplit(
      viewId,
      targetGroupId: location.groupId!,
      direction: direction,
      placement: placement,
      ratio: ratio,
    );
  }

  @override
  void moveViewToSplit(
    String viewId, {
    required String targetGroupId,
    required SplitDirection direction,
    required SplitPlacement placement,
    double ratio = 0.5,
  }) {
    final targetGroup = _state.group(targetGroupId);
    if (targetGroup == null) return;

    final location = _state.locations[viewId];
    final sourceGroupId = location?.groupId;
    final sourceGroup = sourceGroupId != null
        ? _state.group(sourceGroupId)
        : null;

    final root = _state.layoutFor(targetGroup.area);
    if (root == null) return;

    final newGroupId = groupIdGenerator.next();
    final newGroup = ViewGroupState(
      id: newGroupId,
      area: targetGroup.area,
      viewIds: [viewId],
      activeViewId: viewId,
    );

    final nextGroups = Map<String, ViewGroupState>.from(_state.groups)
      ..[newGroupId] = newGroup;

    if (sourceGroup != null) {
      final sourceViews = List<String>.from(sourceGroup.viewIds)
        ..remove(viewId);
      String? sourceActive = sourceGroup.activeViewId;
      if (sourceActive == viewId) {
        sourceActive = sourceViews.isNotEmpty ? sourceViews.last : null;
      }
      nextGroups[sourceGroup.id] = sourceGroup.copyWith(
        viewIds: sourceViews,
        activeViewId: sourceActive,
      );
    }

    final updatedTree = treeEditor.splitGroup(
      root,
      groupId: targetGroupId,
      newGroupId: newGroupId,
      direction: direction,
      placement: placement,
      ratio: ratio,
    );

    final nextAreaLayouts = Map<ViewArea, LayoutNode>.from(_state.areaLayouts)
      ..[targetGroup.area] = updatedTree;

    final nextLocations = Map<String, ViewLocation>.from(_state.locations);
    nextLocations[viewId] = ViewLocation(
      viewId: viewId,
      area: targetGroup.area,
      groupId: newGroupId,
    );

    final nextActiveGroups = Map<ViewArea, String?>.from(_state.activeGroupIds)
      ..[targetGroup.area] = newGroupId;

    _state = _state.copyWith(
      locations: nextLocations,
      groups: nextGroups,
      areaLayouts: nextAreaLayouts,
      activeGroupIds: nextActiveGroups,
    );

    _showPaneForArea(targetGroup.area);
    _commitLayoutChange();
  }

  @override
  void closeSplit(String splitNodeId) {
    final area = treeNavigator.findAreaForSplit(
      _state.areaLayouts,
      splitNodeId,
    );
    if (area == null) return;

    final root = _state.layoutFor(area);
    if (root == null) return;

    final splitNode = treeNavigator.findSplit(root, splitNodeId);
    if (splitNode == null) return;

    // Remove the second branch's groups
    final removedGroupIds = treeNavigator.collectGroupIds(splitNode.second);
    var updatedRoot = root;
    for (final gId in removedGroupIds) {
      final removed = treeEditor.removeGroup(updatedRoot, groupId: gId);
      if (removed != null) updatedRoot = removed;
    }

    final nextAreaLayouts = Map<ViewArea, LayoutNode>.from(_state.areaLayouts)
      ..[area] = updatedRoot;

    final nextGroups = Map<String, ViewGroupState>.from(_state.groups)
      ..removeWhere((k, _) => removedGroupIds.contains(k));

    final nextLocations = Map<String, ViewLocation>.from(_state.locations)
      ..removeWhere((_, loc) => removedGroupIds.contains(loc.groupId));

    final remainingGroupIds = treeNavigator.collectGroupIds(updatedRoot);
    final nextActiveGroups = Map<ViewArea, String?>.from(_state.activeGroupIds);
    if (!remainingGroupIds.contains(nextActiveGroups[area])) {
      nextActiveGroups[area] = remainingGroupIds.isNotEmpty
          ? remainingGroupIds.first
          : null;
    }

    _state = _state.copyWith(
      locations: nextLocations,
      groups: nextGroups,
      areaLayouts: nextAreaLayouts,
      activeGroupIds: nextActiveGroups,
    );

    _commitLayoutChange();
  }

  @override
  void beginSplitResize(String splitNodeId) {
    _activeSplitResizeId = splitNodeId;
  }

  @override
  void resizeSplit(String splitNodeId, double ratio) {
    if (!layoutPolicy.canResizeSplit(splitNodeId)) return;

    final area = treeNavigator.findAreaForSplit(
      _state.areaLayouts,
      splitNodeId,
    );
    if (area == null) return;

    final root = _state.layoutFor(area);
    if (root == null) return;

    final updatedRoot = treeEditor.updateSplitRatio(
      root,
      splitNodeId: splitNodeId,
      ratio: ratio,
    );

    _state = _state.copyWith(
      areaLayouts: {..._state.areaLayouts, area: updatedRoot},
    );

    _notify();
  }

  @override
  void endSplitResize(String splitNodeId) {
    if (_activeSplitResizeId != splitNodeId) return;
    _activeSplitResizeId = null;
    _commitLayoutChange(persist: true);
  }

  void removeViewsOwnedBy(String ownerId) {
    final ownedViewIds = views
        .getAllForOwner(ownerId)
        .map((v) => v.id)
        .where((id) => _state.locations.containsKey(id))
        .toList();

    for (final viewId in ownedViewIds) {
      closeView(viewId);
    }
  }

  void dispose() {
    _stateController.close();
  }
}
