import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import '../layout/tree/layout_node.dart';
import '../layout/view_group_state.dart';
import '../workbench_layout_state.dart';

class LayoutReconciliationResult {
  final WorkbenchLayoutState state;
  final List<LayoutRepair> repairs;

  const LayoutReconciliationResult({
    required this.state,
    required this.repairs,
  });
}

class WorkbenchLayoutReconciler {
  final ViewIdMigration? migration;

  const WorkbenchLayoutReconciler({this.migration});

  LayoutReconciliationResult reconcile(WorkbenchLayoutState state) {
    final repairs = <LayoutRepair>[];
    var reconciledGroups = <String, ViewGroupState>{};
    var reconciledRoots = <ViewArea, LayoutNode>{};

    // 1. Reconcile and migrate view IDs inside view groups
    for (final entry in state.groups.entries) {
      final group = entry.value;
      final newViewIds = <String>[];
      var groupMigrated = false;

      for (final vId in group.viewIds) {
        final migrated = migration?.migrate(vId);
        if (migrated != null && migrated != vId) {
          newViewIds.add(migrated);
          repairs.add(
            MigratedViewIdRepair(oldViewId: vId, newViewId: migrated),
          );
          groupMigrated = true;
        } else {
          newViewIds.add(vId);
        }
      }

      String? activeId = group.activeViewId;
      if (activeId != null) {
        final migratedActive = migration?.migrate(activeId);
        if (migratedActive != null && migratedActive != activeId) {
          activeId = migratedActive;
          groupMigrated = true;
        }
      }

      if (groupMigrated) {
        reconciledGroups[group.id] = group.copyWith(
          viewIds: newViewIds,
          activeViewId: activeId,
        );
      } else {
        reconciledGroups[group.id] = group;
      }
    }

    // 2. Reconcile tree nodes per area (clamping ratios, verifying referenced groups)
    for (final area in ViewArea.values) {
      final rootNode = state.layoutFor(area);
      if (rootNode != null) {
        final (repairedNode, nodeRepairs) = _reconcileNode(
          rootNode,
          area,
          reconciledGroups,
        );
        if (repairedNode != null) {
          reconciledRoots[area] = repairedNode;
        }
        repairs.addAll(nodeRepairs);
      }
    }

    final reconciledState = state.copyWith(
      groups: reconciledGroups,
      areaLayouts: reconciledRoots,
    );

    return LayoutReconciliationResult(state: reconciledState, repairs: repairs);
  }

  (LayoutNode?, List<LayoutRepair>) _reconcileNode(
    LayoutNode node,
    ViewArea area,
    Map<String, ViewGroupState> groups,
  ) {
    final repairs = <LayoutRepair>[];

    if (node is ViewGroupNode) {
      if (!groups.containsKey(node.groupId)) {
        // Create missing group to avoid broken view tree
        groups[node.groupId] = ViewGroupState(
          id: node.groupId,
          area: area,
          viewIds: [],
          activeViewId: null,
        );
        repairs.add(CreatedMissingGroupRepair(groupId: node.groupId));
      }
      return (node, repairs);
    } else if (node is SplitNode) {
      double ratio = node.ratio;
      if (ratio < 0.05 || ratio > 0.95) {
        final clamped = ratio.clamp(0.05, 0.95);
        repairs.add(
          ClampedSplitRatioRepair(
            splitNodeId: node.id,
            oldRatio: ratio,
            newRatio: clamped,
          ),
        );
        ratio = clamped;
      }

      final (firstRepaired, firstRepairs) = _reconcileNode(
        node.first,
        area,
        groups,
      );
      final (secondRepaired, secondRepairs) = _reconcileNode(
        node.second,
        area,
        groups,
      );
      repairs.addAll(firstRepairs);
      repairs.addAll(secondRepairs);

      if (firstRepaired == null && secondRepaired == null) {
        return (null, repairs);
      }
      if (firstRepaired == null) return (secondRepaired, repairs);
      if (secondRepaired == null) return (firstRepaired, repairs);

      final updatedSplit = SplitNode(
        id: node.id,
        direction: node.direction,
        ratio: ratio,
        first: firstRepaired,
        second: secondRepaired,
      );

      return (updatedSplit, repairs);
    }

    return (node, repairs);
  }
}
