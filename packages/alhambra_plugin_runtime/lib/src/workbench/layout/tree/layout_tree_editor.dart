import 'layout_node.dart';
import 'split_direction.dart';

class LayoutTreeEditor {
  const LayoutTreeEditor();

  LayoutNode splitGroup(
    LayoutNode node, {
    required String groupId,
    required String newGroupId,
    required SplitDirection direction,
    required SplitPlacement placement,
    double ratio = 0.5,
  }) {
    if (node case ViewGroupNode()) {
      if (node.groupId != groupId) {
        return node;
      }

      final newNode = ViewGroupNode(
        id: 'node.$newGroupId',
        groupId: newGroupId,
      );

      final oldNode = node;

      return placement == SplitPlacement.before
          ? SplitNode(
              id: 'split.${newNode.groupId}.${oldNode.groupId}',
              direction: direction,
              first: newNode,
              second: oldNode,
              ratio: ratio,
            )
          : SplitNode(
              id: 'split.${oldNode.groupId}.${newNode.groupId}',
              direction: direction,
              first: oldNode,
              second: newNode,
              ratio: ratio,
            );
    }

    if (node case SplitNode()) {
      return SplitNode(
        id: node.id,
        direction: node.direction,
        ratio: node.ratio,
        first: splitGroup(
          node.first,
          groupId: groupId,
          newGroupId: newGroupId,
          direction: direction,
          placement: placement,
          ratio: ratio,
        ),
        second: splitGroup(
          node.second,
          groupId: groupId,
          newGroupId: newGroupId,
          direction: direction,
          placement: placement,
          ratio: ratio,
        ),
      );
    }

    return node;
  }

  LayoutNode updateSplitRatio(
    LayoutNode node, {
    required String splitNodeId,
    required double ratio,
  }) {
    if (node case ViewGroupNode()) {
      return node;
    }

    if (node case SplitNode()) {
      final normalizedRatio = ratio.clamp(0.05, 0.95);

      if (node.id == splitNodeId) {
        return SplitNode(
          id: node.id,
          direction: node.direction,
          ratio: normalizedRatio,
          first: node.first,
          second: node.second,
        );
      }

      return SplitNode(
        id: node.id,
        direction: node.direction,
        ratio: node.ratio,
        first: updateSplitRatio(
          node.first,
          splitNodeId: splitNodeId,
          ratio: ratio,
        ),
        second: updateSplitRatio(
          node.second,
          splitNodeId: splitNodeId,
          ratio: ratio,
        ),
      );
    }

    return node;
  }

  LayoutNode? removeGroup(
    LayoutNode root, {
    required String groupId,
  }) {
    if (root case ViewGroupNode()) {
      if (root.groupId == groupId) {
        return null;
      }
      return root;
    }

    if (root case SplitNode()) {
      // Check first branch
      if (root.first case ViewGroupNode(groupId: final gId) when gId == groupId) {
        return root.second;
      }
      // Check second branch
      if (root.second case ViewGroupNode(groupId: final gId) when gId == groupId) {
        return root.first;
      }

      final newFirst = removeGroup(root.first, groupId: groupId);
      final newSecond = removeGroup(root.second, groupId: groupId);

      if (newFirst == null && newSecond != null) {
        return newSecond;
      }
      if (newSecond == null && newFirst != null) {
        return newFirst;
      }
      if (newFirst == null && newSecond == null) {
        return null;
      }

      return SplitNode(
        id: root.id,
        direction: root.direction,
        ratio: root.ratio,
        first: newFirst!,
        second: newSecond!,
      );
    }

    return root;
  }

  LayoutNode replaceGroup(
    LayoutNode node, {
    required String oldGroupId,
    required String newGroupId,
  }) {
    if (node case ViewGroupNode()) {
      if (node.groupId == oldGroupId) {
        return ViewGroupNode(
          id: 'node.$newGroupId',
          groupId: newGroupId,
        );
      }
      return node;
    }

    if (node case SplitNode()) {
      return SplitNode(
        id: node.id,
        direction: node.direction,
        ratio: node.ratio,
        first: replaceGroup(
          node.first,
          oldGroupId: oldGroupId,
          newGroupId: newGroupId,
        ),
        second: replaceGroup(
          node.second,
          oldGroupId: oldGroupId,
          newGroupId: newGroupId,
        ),
      );
    }

    return node;
  }
}
