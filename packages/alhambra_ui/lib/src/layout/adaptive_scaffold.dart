import 'package:flutter/material.dart';
import '../navigation/navigation_item.dart';
import '../theme/dimensions.dart';
import 'responsive_layout.dart';

/// An adaptive application scaffold that renders:
/// - A bottom navigation bar on compact screens
/// - A navigation rail on medium screens
/// - A persistent side navigation drawer on expanded screens
class AdaptiveScaffold extends StatelessWidget {
  final List<NavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;

  const AdaptiveScaffold({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.appBar,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      builder: (context, screenSize) {
        if (screenSize.isCompact) {
          return Scaffold(
            appBar: appBar,
            body: body,
            floatingActionButton: floatingActionButton,
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: items
                  .map(
                    (item) => NavigationDestination(
                      icon: Icon(item.icon ?? Icons.circle_outlined),
                      selectedIcon: Icon(item.selectedIcon ?? item.icon ?? Icons.circle),
                      label: item.label,
                    ),
                  )
                  .toList(),
            ),
          );
        }

        if (screenSize.isMedium) {
          return Scaffold(
            appBar: appBar,
            floatingActionButton: floatingActionButton,
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  labelType: NavigationRailLabelType.selected,
                  destinations: items
                      .map(
                        (item) => NavigationRailDestination(
                          icon: Icon(item.icon ?? Icons.circle_outlined),
                          selectedIcon: Icon(item.selectedIcon ?? item.icon ?? Icons.circle),
                          label: Text(item.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        // Expanded screen
        return Scaffold(
          appBar: appBar,
          floatingActionButton: floatingActionButton,
          body: Row(
            children: [
              SizedBox(
                width: AlhambraDimensions.navSidebarWidth,
                child: Drawer(
                  elevation: 0,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      DrawerHeader(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                        child: Text(
                          'Alhambra',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      ...items.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final isSelected = idx == selectedIndex;
                        return ListTile(
                          leading: Icon(item.icon ?? Icons.circle_outlined),
                          title: Text(item.label),
                          selected: isSelected,
                          onTap: () => onDestinationSelected(idx),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}
