import 'package:flutter/material.dart';
import '../theme/spacing.dart';

/// A standard detail page layout with header, scrollable body, and optional actions.
class DetailLayout extends StatelessWidget {
  final Widget header;
  final Widget body;
  final Widget? sidebar;
  final List<Widget>? actions;

  const DetailLayout({
    super.key,
    required this.header,
    required this.body,
    this.sidebar,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AlhambraSpacing.md),
          child: Row(
            children: [
              Expanded(child: header),
              if (actions != null) ...actions!,
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: body),
              if (sidebar != null) ...[
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 300,
                  child: sidebar!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
