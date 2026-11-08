import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import '../pane_id.dart';
import '../pane_state.dart';
import '../view_group_state.dart';
import '../../view_location.dart';
import 'layout_node.dart';

class WorkbenchLayoutValidator {
  const WorkbenchLayoutValidator();

  void validate({
    required Map<PaneId, PaneState> panes,
    required Map<String, ViewLocation> locations,
    required Map<String, ViewGroupState> groups,
    required Map<ViewArea, LayoutNode> areaLayouts,
  }) {
    final seenGroupIds = <String>{};

    for (final entry in areaLayouts.entries) {
      _validateNode(
        area: entry.key,
        node: entry.value,
        groups: groups,
        seenGroupIds: seenGroupIds,
      );
    }

    // Validate locations
    for (final loc in locations.values) {
      if (loc.groupId != null) {
        final group = groups[loc.groupId];
        if (group == null) {
          throw StateError(
            'Location for view "${loc.viewId}" references unknown group "${loc.groupId}"',
          );
        }
        if (group.area != loc.area) {
          throw StateError(
            'Location area (${loc.area}) for view "${loc.viewId}" does not match group area (${group.area})',
          );
        }
      }
    }
  }

  void _validateNode({
    required ViewArea area,
    required LayoutNode node,
    required Map<String, ViewGroupState> groups,
    required Set<String> seenGroupIds,
  }) {
    switch (node) {
      case ViewGroupNode():
        if (seenGroupIds.contains(node.groupId)) {
          throw StateError(
            'Duplicate group ID in layout tree: ${node.groupId}',
          );
        }
        seenGroupIds.add(node.groupId);

        final group = groups[node.groupId];
        if (group == null) {
          throw StateError(
            'Layout node "${node.id}" references missing group: "${node.groupId}"',
          );
        }
        if (group.area != area) {
          throw StateError(
            'Group "${group.id}" (area ${group.area}) belongs to wrong area tree ($area)',
          );
        }

      case SplitNode():
        if (node.ratio <= 0.0 || node.ratio >= 1.0) {
          throw StateError(
            'SplitNode "${node.id}" has invalid ratio: ${node.ratio}. Must be between 0.0 and 1.0',
          );
        }
        _validateNode(
          area: area,
          node: node.first,
          groups: groups,
          seenGroupIds: seenGroupIds,
        );
        _validateNode(
          area: area,
          node: node.second,
          groups: groups,
          seenGroupIds: seenGroupIds,
        );
    }
  }
}
