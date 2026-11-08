import 'navigation_item.dart';

/// A logical grouping of [NavigationItem]s in the navigation menu or sidebar.
final class NavigationSection {
  final String id;
  final String label;
  final List<NavigationItem> items;

  const NavigationSection({
    required this.id,
    required this.label,
    required this.items,
  });

  @override
  String toString() => 'NavigationSection($id, items: ${items.length})';
}
