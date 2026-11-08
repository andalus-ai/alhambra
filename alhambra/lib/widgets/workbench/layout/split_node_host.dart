import 'package:flutter/material.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'layout_node_host.dart';
import 'split_divider.dart';

class SplitNodeHost extends StatelessWidget {
  final SplitNode node;

  const SplitNodeHost({
    super.key,
    required this.node,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSize = node.direction == SplitDirection.horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;

        final firstFlex = (node.ratio * 1000).round().clamp(1, 999);
        final secondFlex = 1000 - firstFlex;

        final firstChild = Expanded(
          flex: firstFlex,
          child: LayoutNodeHost(node: node.first),
        );

        final secondChild = Expanded(
          flex: secondFlex,
          child: LayoutNodeHost(node: node.second),
        );

        final divider = SplitDivider(
          node: node,
          totalSize: totalSize,
        );

        return switch (node.direction) {
          SplitDirection.horizontal => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                firstChild,
                divider,
                secondChild,
              ],
            ),
          SplitDirection.vertical => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                firstChild,
                divider,
                secondChild,
              ],
            ),
        };
      },
    );
  }
}
