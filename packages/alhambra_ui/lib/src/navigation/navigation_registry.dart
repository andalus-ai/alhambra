import 'navigation_section.dart';

/// Registry contract for modular contribution of navigation sections and items.
abstract interface class NavigationRegistry {
  /// Unmodifiable view of registered sections.
  List<NavigationSection> get sections;

  /// Registers a new section.
  void register(NavigationSection section);

  /// Unregisters an existing section by [id].
  void unregister(String id);
}

/// In-memory implementation of [NavigationRegistry].
final class DefaultNavigationRegistry implements NavigationRegistry {
  final List<NavigationSection> _sections = [];

  DefaultNavigationRegistry([List<NavigationSection>? initialSections]) {
    if (initialSections != null) {
      _sections.addAll(initialSections);
    }
  }

  @override
  List<NavigationSection> get sections => List.unmodifiable(_sections);

  @override
  void register(NavigationSection section) {
    _sections.removeWhere((s) => s.id == section.id);
    _sections.add(section);
  }

  @override
  void unregister(String id) {
    _sections.removeWhere((s) => s.id == id);
  }
}
