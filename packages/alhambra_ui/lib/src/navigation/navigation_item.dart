import 'package:flutter/widgets.dart';

/// Represents a single navigable destination in the shell or workspace.
final class NavigationItem {
  final String id;
  final String label;
  final IconData? icon;
  final IconData? selectedIcon;
  final String? route;
  final String? badge;
  final String? requiredPermission;
  final Map<String, Object?> metadata;

  const NavigationItem({
    required this.id,
    required this.label,
    this.icon,
    this.selectedIcon,
    this.route,
    this.badge,
    this.requiredPermission,
    this.metadata = const {},
  });

  @override
  String toString() => 'NavigationItem($id, label: $label, route: $route)';
}
