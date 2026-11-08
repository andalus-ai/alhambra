import 'package:flutter/material.dart';
import 'workspace_header.dart';
import 'workspace_navigation.dart';
import 'ui_workspace_status.dart';

/// Generic workspace presentation shell.
///
/// The identifier is opaque so this widget does not depend on a particular
/// workspace domain model or repository package.
class WorkspaceShell extends StatelessWidget {
  final String workspaceId;
  final String title;
  final UiWorkspaceStatus status;
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
