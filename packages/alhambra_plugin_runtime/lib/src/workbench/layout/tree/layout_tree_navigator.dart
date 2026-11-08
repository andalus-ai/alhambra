import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'layout_node.dart';

class LayoutTreeNavigator {
  const LayoutTreeNavigator();

  ViewGroupNode? findGroupNode(LayoutNode root, String groupId) {
    if (root case ViewGroupNode()) {
      return root.groupId == groupId ? root : null;
    }
    if (root case SplitNode()) {
      return findGroupNode(root.first, groupId) ??
          findGroupNode(root.second, groupId);
    }
    return null;
  }

  SplitNode? findSplit(LayoutNode root, String splitNodeId) {
    if (root case ViewGroupNode()) {
      return null;
    }
    if (root case SplitNode()) {
      if (root.id == splitNodeId) return root;
      return findSplit(root.first, splitNodeId) ??
          findSplit(root.second, splitNodeId);
    }
    return null;
  }

  String? findParentSplitId(LayoutNode root, String nodeId) {
    if (root case ViewGroupNode()) {
      return null;
    }
    if (root case SplitNode()) {
      if (root.first.id == nodeId || root.second.id == nodeId) {
        return root.id;
      }
      return findParentSplitId(root.first, nodeId) ??
          findParentSplitId(root.second, nodeId);
    }
    return null;
  }

  List<String> collectGroupIds(LayoutNode root) {
    final ids = <String>[];
    _collectGroups(root, ids);
    return ids;
  }

  void _collectGroups(LayoutNode node, List<String> result) {
    if (node case ViewGroupNode()) {
      result.add(node.groupId);
    } else if (node case SplitNode()) {
      _collectGroups(node.first, result);
      _collectGroups(node.second, result);
    }
  }

  List<String> collectSplitIds(LayoutNode root) {
    final ids = <String>[];
    _collectSplits(root, ids);
    return ids;
  }

  void _collectSplits(LayoutNode node, List<String> result) {
    if (node case SplitNode()) {
      result.add(node.id);
      _collectSplits(node.first, result);
      _collectSplits(node.second, result);
    }
  }

  bool containsSplit(LayoutNode root, String splitNodeId) {
    return findSplit(root, splitNodeId) != null;
  }

  bool containsGroup(LayoutNode root, String groupId) {
    return findGroupNode(root, groupId) != null;
  }

  ViewArea? findAreaForGroup(
    Map<ViewArea, LayoutNode> areaLayouts,
    String groupId,
  ) {
    for (final entry in areaLayouts.entries) {
      if (containsGroup(entry.value, groupId)) {
        return entry.key;
      }
    }
    return null;
  }

  ViewArea? findAreaForSplit(
    Map<ViewArea, LayoutNode> areaLayouts,
    String splitNodeId,
  ) {
    for (final entry in areaLayouts.entries) {
      if (containsSplit(entry.value, splitNodeId)) {
        return entry.key;
      }
    }
    return null;
  }
}
