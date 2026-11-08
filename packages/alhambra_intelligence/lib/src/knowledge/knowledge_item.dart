/// An external or institutional knowledge entity accessible to intelligence agents.
final class KnowledgeItem {
  final String id;
  final String title;
  final String content;
  final Map<String, Object?> metadata;

  const KnowledgeItem({
    required this.id,
    required this.title,
    required this.content,
    this.metadata = const {},
  });

  @override
  String toString() => 'KnowledgeItem($id: "$title")';
}
