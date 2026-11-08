import 'package:flutter/material.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'split_node_host.dart';
import 'view_group_host.dart';

class LayoutNodeHost extends StatelessWidget {
  final LayoutNode node;

  const LayoutNodeHost({
    super.key,
    required this.node,
  });

  @override
  Widget build(BuildContext context) {
    final currentNode = node;
    if (currentNode is ViewGroupNode) {
      return ViewGroupHost(groupId: currentNode.groupId);
    }
    if (currentNode is SplitNode) {
      return SplitNodeHost(node: currentNode);
    }
    return const SizedBox.shrink();
  }
}
