import 'ui_node.dart';

/// Represents a standalone declarative UI surface produced dynamically.
final class UiSurface {
  final String id;
  final String title;
  final UiNode rootNode;
  final Map<String, Object?> metadata;

  const UiSurface({
    required this.id,
    required this.title,
    required this.rootNode,
    this.metadata = const {},
  });

  @override
  String toString() => 'UiSurface($id: $title)';
}
