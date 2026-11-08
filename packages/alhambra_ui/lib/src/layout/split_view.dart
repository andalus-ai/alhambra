import 'package:flutter/material.dart';
import 'responsive_layout.dart';

/// Two-pane split view that displays master and detail side-by-side on wide screens,
/// or collapses to a single pane on compact screens.
class SplitView extends StatelessWidget {
  final Widget master;
  final Widget detail;
  final double masterWidth;

  const SplitView({
    super.key,
    required this.master,
    required this.detail,
    this.masterWidth = 320.0,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      builder: (context, screenSize) {
        if (screenSize.isCompact) {
          // On compact screen, detail takes priority if both are rendered, or master
          return master;
        }

        return Row(
          children: [
            SizedBox(
              width: masterWidth,
              child: master,
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: detail),
          ],
        );
      },
    );
  }
}
