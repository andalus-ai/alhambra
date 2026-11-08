import 'package:flutter/material.dart';

class PluginBottomNav extends StatelessWidget {
  final Function(int) onTabSelected;

  const PluginBottomNav({
    super.key,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabs = ['General', 'Capabilities', 'Time and focus'];
    final icons = [Icons.settings, Icons.tune, Icons.timer];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxTabWidth = constraints.maxWidth / tabs.length;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(tabs.length, (index) {
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: maxTabWidth.clamp(72.0, 120.0),
                  ),
                  child: InkWell(
                    onTap: () => onTabSelected(index),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icons[index],
                            color: index == 0
                                ? Colors.blue
                                : isDark
                                    ? Colors.grey[500]
                                    : Colors.grey[600],
                            size: 22,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tabs[index],
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            softWrap: false,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: index == 0
                                  ? Colors.blue
                                  : isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[600],
                              fontSize: 12,
                              fontWeight: index == 0
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}
