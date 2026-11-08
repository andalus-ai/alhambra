class NavigationGroup {
  final String id;
  final String title;
  final int order;

  const NavigationGroup({
    required this.id,
    required this.title,
    this.order = 0,
  });
}

class BuiltInNavigationGroups {
  static const project = NavigationGroup(id: 'project', title: 'PROJECT', order: 10);
  static const workspace = NavigationGroup(id: 'workspace', title: 'WORKSPACE', order: 20);
  static const tools = NavigationGroup(id: 'tools', title: 'TOOLS', order: 30);
  static const management = NavigationGroup(id: 'management', title: 'MANAGEMENT', order: 40);
}
