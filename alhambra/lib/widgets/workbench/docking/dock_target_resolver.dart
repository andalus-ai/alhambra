import 'package:flutter/material.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'dock_drag_data.dart';
import 'dock_target.dart';
import 'drop_intent.dart';

class DockTargetResolver {
  final WorkbenchLayoutPolicy policy;

  const DockTargetResolver({
    this.policy = const DefaultWorkbenchLayoutPolicy(),
  });

  DropIntent resolve({
    required DockDragData data,
    required Offset position,
    required Iterable<DockTarget> targets,
  }) {
    final target = _findTarget(position, targets);
    if (target == null) {
      return const NoDropIntent();
    }

    final zone = _resolveZone(position, target);
    return _intentFor(data, target, zone, position);
  }

  DockTarget? _findTarget(Offset position, Iterable<DockTarget> targets) {
    for (final target in targets) {
      if (target.bounds.contains(position) ||
          target.tabStripBounds.contains(position)) {
        return target;
      }
    }
    return null;
  }

  DockZone _resolveZone(Offset position, DockTarget target) {
    if (target.tabStripBounds.contains(position)) {
      return DockZone.tabStrip;
    }
    return _resolveContentZone(position, target.bounds);
  }

  DockZone _resolveContentZone(Offset position, Rect bounds) {
    if (bounds.width <= 0 || bounds.height <= 0) {
      return DockZone.outside;
    }

    final x = (position.dx - bounds.left) / bounds.width;
    final y = (position.dy - bounds.top) / bounds.height;

    const edge = 0.25;

    if (x <= edge) return DockZone.left;
    if (x >= 1.0 - edge) return DockZone.right;
    if (y <= edge) return DockZone.top;
    if (y >= 1.0 - edge) return DockZone.bottom;

    return DockZone.center;
  }

  DropIntent _intentFor(
    DockDragData data,
    DockTarget target,
    DockZone zone,
    Offset position,
  ) {
    switch (zone) {
      case DockZone.tabStrip:
        final index = _resolveTabIndex(position, target);
        return ReorderDropIntent(
          targetGroupId: target.groupId,
          index: index,
        );

      case DockZone.center:
        if (!policy.canDockViewToGroup(data.viewId, target.groupId)) {
          return const NoDropIntent();
        }
        return MoveToGroupDropIntent(
          targetGroupId: target.groupId,
        );

      case DockZone.left:
        if (!policy.canSplitViewAtGroup(data.viewId, target.groupId)) {
          return const NoDropIntent();
        }
        return SplitDropIntent(
          targetGroupId: target.groupId,
          side: DockSide.left,
        );

      case DockZone.right:
        if (!policy.canSplitViewAtGroup(data.viewId, target.groupId)) {
          return const NoDropIntent();
        }
        return SplitDropIntent(
          targetGroupId: target.groupId,
          side: DockSide.right,
        );

      case DockZone.top:
        if (!policy.canSplitViewAtGroup(data.viewId, target.groupId)) {
          return const NoDropIntent();
        }
        return SplitDropIntent(
          targetGroupId: target.groupId,
          side: DockSide.top,
        );

      case DockZone.bottom:
        if (!policy.canSplitViewAtGroup(data.viewId, target.groupId)) {
          return const NoDropIntent();
        }
        return SplitDropIntent(
          targetGroupId: target.groupId,
          side: DockSide.bottom,
        );

      case DockZone.outside:
        return const NoDropIntent();
    }
  }

  int _resolveTabIndex(Offset position, DockTarget target) {
    if (target.tabs.isEmpty) return 0;

    for (final tab in target.tabs) {
      if (position.dx < tab.bounds.center.dx) {
        return tab.index;
      }
    }
    return target.tabs.length;
  }
}
