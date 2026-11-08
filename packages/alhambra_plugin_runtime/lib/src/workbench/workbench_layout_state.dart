import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'layout/pane_id.dart';
import 'layout/pane_state.dart';
import 'layout/tree/layout_node.dart';
import 'layout/view_group_id.dart';
import 'layout/view_group_state.dart';
import 'view_location.dart';

class WorkbenchPanelDimensions {
  final double sidebarWidth;
  final double secondaryWidth;
  final double bottomHeight;
  final bool isSidebarVisible;
  final bool isSecondaryVisible;
  final bool isBottomVisible;

  const WorkbenchPanelDimensions({
    this.sidebarWidth = 280.0,
    this.secondaryWidth = 300.0,
    this.bottomHeight = 240.0,
    this.isSidebarVisible = true,
    this.isSecondaryVisible = false,
    this.isBottomVisible = false,
  });

  WorkbenchPanelDimensions copyWith({
    double? sidebarWidth,
    double? secondaryWidth,
    double? bottomHeight,
    bool? isSidebarVisible,
    bool? isSecondaryVisible,
    bool? isBottomVisible,
  }) {
    return WorkbenchPanelDimensions(
      sidebarWidth: (sidebarWidth ?? this.sidebarWidth).clamp(160.0, 700.0),
      secondaryWidth: (secondaryWidth ?? this.secondaryWidth).clamp(
        180.0,
        700.0,
      ),
      bottomHeight: (bottomHeight ?? this.bottomHeight).clamp(80.0, 600.0),
      isSidebarVisible: isSidebarVisible ?? this.isSidebarVisible,
      isSecondaryVisible: isSecondaryVisible ?? this.isSecondaryVisible,
      isBottomVisible: isBottomVisible ?? this.isBottomVisible,
    );
  }

  Map<String, dynamic> toJson() => {
    'sidebarWidth': sidebarWidth,
    'secondaryWidth': secondaryWidth,
    'bottomHeight': bottomHeight,
    'isSidebarVisible': isSidebarVisible,
    'isSecondaryVisible': isSecondaryVisible,
    'isBottomVisible': isBottomVisible,
  };

  factory WorkbenchPanelDimensions.fromJson(Map<String, dynamic> json) {
    return WorkbenchPanelDimensions(
      sidebarWidth: (json['sidebarWidth'] as num?)?.toDouble() ?? 280.0,
      secondaryWidth: (json['secondaryWidth'] as num?)?.toDouble() ?? 300.0,
      bottomHeight: (json['bottomHeight'] as num?)?.toDouble() ?? 240.0,
      isSidebarVisible: json['isSidebarVisible'] as bool? ?? true,
      isSecondaryVisible: json['isSecondaryVisible'] as bool? ?? false,
      isBottomVisible: json['isBottomVisible'] as bool? ?? false,
    );
  }
}

class WorkbenchLayoutState {
  final Map<PaneId, PaneState> panes;
  final Map<String, ViewLocation> locations;
  final Map<String, ViewGroupState> groups;
  final Map<ViewArea, LayoutNode> areaLayouts;
  final Map<ViewArea, String?> activeGroupIds;
  final String? activeActivityId;

  const WorkbenchLayoutState({
    required this.panes,
    required this.locations,
    required this.groups,
    required this.areaLayouts,
    required this.activeGroupIds,
    this.activeActivityId,
  });

  factory WorkbenchLayoutState.defaults() {
    return const WorkbenchLayoutState(
      panes: {
        PaneId.sidebar: PaneState.visible(size: 280),
        PaneId.main: PaneState.visible(),
        PaneId.bottom: PaneState.hidden(),
        PaneId.secondary: PaneState.hidden(),
      },
      locations: {},
      groups: {
        CoreViewGroups.sidebar: ViewGroupState(
          id: CoreViewGroups.sidebar,
          area: ViewArea.sidebar,
          viewIds: [],
          activeViewId: null,
        ),
        CoreViewGroups.main: ViewGroupState(
          id: CoreViewGroups.main,
          area: ViewArea.main,
          viewIds: [],
          activeViewId: null,
        ),
        CoreViewGroups.bottom: ViewGroupState(
          id: CoreViewGroups.bottom,
          area: ViewArea.bottomPanel,
          viewIds: [],
          activeViewId: null,
        ),
        CoreViewGroups.secondary: ViewGroupState(
          id: CoreViewGroups.secondary,
          area: ViewArea.secondaryPanel,
          viewIds: [],
          activeViewId: null,
        ),
      },
      areaLayouts: {
        ViewArea.sidebar: ViewGroupNode(
          id: 'node.sidebar.root',
          groupId: CoreViewGroups.sidebar,
        ),
        ViewArea.main: ViewGroupNode(
          id: 'node.main.root',
          groupId: CoreViewGroups.main,
        ),
        ViewArea.bottomPanel: ViewGroupNode(
          id: 'node.bottom.root',
          groupId: CoreViewGroups.bottom,
        ),
        ViewArea.secondaryPanel: ViewGroupNode(
          id: 'node.secondary.root',
          groupId: CoreViewGroups.secondary,
        ),
      },
      activeGroupIds: {
        ViewArea.sidebar: CoreViewGroups.sidebar,
        ViewArea.main: CoreViewGroups.main,
        ViewArea.bottomPanel: CoreViewGroups.bottom,
        ViewArea.secondaryPanel: CoreViewGroups.secondary,
      },
      activeActivityId: null,
    );
  }

  factory WorkbenchLayoutState.empty() => WorkbenchLayoutState.defaults();

  PaneState pane(PaneId id) => panes[id] ?? const PaneState.hidden();

  ViewGroupState? group(String groupId) => groups[groupId];

  Iterable<ViewGroupState> groupsIn(ViewArea area) {
    return groups.values.where((g) => g.area == area);
  }

  LayoutNode? layoutFor(ViewArea area) => areaLayouts[area];

  String? activeGroupId(ViewArea area) => activeGroupIds[area];

  String? activeViewIn(ViewArea area) {
    final activeGId = activeGroupIds[area];
    if (activeGId != null && groups[activeGId] != null) {
      final active = groups[activeGId]?.activeViewId;
      if (active != null) return active;
    }
    for (final g in groupsIn(area)) {
      if (g.activeViewId != null) return g.activeViewId;
      if (g.viewIds.isNotEmpty) return g.viewIds.first;
    }
    return null;
  }

  List<String> viewsIn(ViewArea area) {
    final list = <String>[];
    for (final g in groupsIn(area)) {
      list.addAll(g.viewIds);
    }
    return list;
  }

  ViewLocation? locationOf(String viewId) => locations[viewId];

  // Backward compatibility properties
  Map<ViewArea, List<String>> get openViews => {
    for (final area in ViewArea.values) area: viewsIn(area),
  };

  Map<ViewArea, String?> get activeViews => {
    for (final area in ViewArea.values) area: activeViewIn(area),
  };

  WorkbenchPanelDimensions get dimensions => WorkbenchPanelDimensions(
    sidebarWidth: pane(PaneId.sidebar).size ?? 280.0,
    secondaryWidth: pane(PaneId.secondary).size ?? 300.0,
    bottomHeight: pane(PaneId.bottom).size ?? 240.0,
    isSidebarVisible: pane(PaneId.sidebar).visible,
    isSecondaryVisible: pane(PaneId.secondary).visible,
    isBottomVisible: pane(PaneId.bottom).visible,
  );

  WorkbenchLayoutState copyWith({
    Map<PaneId, PaneState>? panes,
    Map<String, ViewLocation>? locations,
    Map<String, ViewGroupState>? groups,
    Map<ViewArea, LayoutNode>? areaLayouts,
    Map<ViewArea, String?>? activeGroupIds,
    String? activeActivityId,
    // Dimension helper for backward compatibility
    WorkbenchPanelDimensions? dimensions,
  }) {
    var resolvedPanes = panes ?? this.panes;
    if (dimensions != null) {
      final sidebarState =
          resolvedPanes[PaneId.sidebar] ?? const PaneState.visible(size: 280);
      final secondaryState =
          resolvedPanes[PaneId.secondary] ?? const PaneState.hidden();
      final bottomState =
          resolvedPanes[PaneId.bottom] ?? const PaneState.hidden();

      resolvedPanes = {
        ...resolvedPanes,
        PaneId.sidebar: sidebarState.copyWith(
          visible: dimensions.isSidebarVisible,
          size: dimensions.sidebarWidth,
        ),
        PaneId.secondary: secondaryState.copyWith(
          visible: dimensions.isSecondaryVisible,
          size: dimensions.secondaryWidth,
        ),
        PaneId.bottom: bottomState.copyWith(
          visible: dimensions.isBottomVisible,
          size: dimensions.bottomHeight,
        ),
      };
    }

    return WorkbenchLayoutState(
      panes: resolvedPanes,
      locations: locations ?? this.locations,
      groups: groups ?? this.groups,
      areaLayouts: areaLayouts ?? this.areaLayouts,
      activeGroupIds: activeGroupIds ?? this.activeGroupIds,
      activeActivityId: activeActivityId ?? this.activeActivityId,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 2,
    'panes': {
      for (final entry in panes.entries) entry.key.name: entry.value.toJson(),
    },
    'locations': {
      for (final entry in locations.entries) entry.key: entry.value.toJson(),
    },
    'groups': {
      for (final entry in groups.entries) entry.key: entry.value.toJson(),
    },
    'areaLayouts': {
      for (final entry in areaLayouts.entries)
        entry.key.name: entry.value.toJson(),
    },
    'activeGroupIds': {
      for (final entry in activeGroupIds.entries)
        if (entry.value != null) entry.key.name: entry.value,
    },
    if (activeActivityId != null) 'activeActivityId': activeActivityId,
  };

  factory WorkbenchLayoutState.fromJson(Map<String, dynamic> json) {
    final defaults = WorkbenchLayoutState.defaults();

    final panesMap = <PaneId, PaneState>{};
    if (json['panes'] is Map) {
      final pMap = json['panes'] as Map<String, dynamic>;
      for (final p in PaneId.values) {
        if (pMap[p.name] is Map) {
          panesMap[p] = PaneState.fromJson(
            pMap[p.name] as Map<String, dynamic>,
          );
        } else {
          panesMap[p] = defaults.pane(p);
        }
      }
    } else {
      panesMap.addAll(defaults.panes);
    }

    final locationsMap = <String, ViewLocation>{};
    if (json['locations'] is Map) {
      final lMap = json['locations'] as Map<String, dynamic>;
      for (final entry in lMap.entries) {
        if (entry.value is Map) {
          locationsMap[entry.key] = ViewLocation.fromJson(
            entry.value as Map<String, dynamic>,
          );
        }
      }
    }

    final groupsMap = <String, ViewGroupState>{};
    if (json['groups'] is Map) {
      final gMap = json['groups'] as Map<String, dynamic>;
      for (final entry in gMap.entries) {
        if (entry.value is Map) {
          groupsMap[entry.key] = ViewGroupState.fromJson(
            entry.value as Map<String, dynamic>,
          );
        }
      }
    } else {
      groupsMap.addAll(defaults.groups);
    }

    final areaLayoutsMap = <ViewArea, LayoutNode>{};
    if (json['areaLayouts'] is Map) {
      final aMap = json['areaLayouts'] as Map<String, dynamic>;
      for (final area in ViewArea.values) {
        if (aMap[area.name] is Map) {
          areaLayoutsMap[area] = LayoutNode.fromJson(
            aMap[area.name] as Map<String, dynamic>,
          );
        } else {
          areaLayoutsMap[area] = defaults.areaLayouts[area]!;
        }
      }
    } else {
      areaLayoutsMap.addAll(defaults.areaLayouts);
    }

    final activeGroupIdsMap = <ViewArea, String?>{};
    if (json['activeGroupIds'] is Map) {
      final agMap = json['activeGroupIds'] as Map<String, dynamic>;
      for (final area in ViewArea.values) {
        activeGroupIdsMap[area] = agMap[area.name] as String?;
      }
    } else {
      activeGroupIdsMap.addAll(defaults.activeGroupIds);
    }

    return WorkbenchLayoutState(
      panes: panesMap,
      locations: locationsMap,
      groups: groupsMap,
      areaLayouts: areaLayoutsMap,
      activeGroupIds: activeGroupIdsMap,
      activeActivityId: json['activeActivityId'] as String?,
    );
  }
}
