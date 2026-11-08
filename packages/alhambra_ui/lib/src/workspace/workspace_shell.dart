import 'package:alhambra_workspace/alhambra_workspace.dart';
import 'package:flutter/material.dart';
import 'workspace_header.dart';
import 'workspace_navigation.dart';

/// Complete workspace view container with header, extensible navigation tabs,
/// and child body view.
class WorkspaceShell extends StatelessWidget {
  final WorkspaceId workspaceId;
  final String title;
  final WorkspaceStatus status;
  final int version;
  final String? subtitle;
  final List<Widget>? headerActions;
  final List<WorkspaceNavigationItem> navigationItems;
  final int selectedNavIndex;
  final ValueChanged<int>? onNavItemSelected;
  final Widget child;

  const WorkspaceShell({
    super.key,
    required this.workspaceId,
    required this.title,
    required this.status,
    required this.child,
    this.version = 1,
    this.subtitle,
    this.headerActions,
    this.navigationItems = const [],
    this.selectedNavIndex = 0,
    this.onNavItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkspaceHeader(
          title: title,
          status: status,
          version: version,
          subtitle: subtitle,
          actions: headerActions,
        ),
        if (navigationItems.isNotEmpty)
          WorkspaceNavigationBar(
            items: navigationItems,
            selectedIndex: selectedNavIndex,
            onItemSelected: onNavItemSelected ?? (_) {},
          ),
        Expanded(child: child),
      ],
    );
  }
}
