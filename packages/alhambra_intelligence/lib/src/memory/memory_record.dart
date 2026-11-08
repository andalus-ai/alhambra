/// A discrete piece of remembered information accumulated from prior executions or sessions.
final class MemoryRecord {
  final String id;
  final String content;
  final DateTime createdAt;
  final Map<String, Object?> metadata;

  const MemoryRecord({
    required this.id,
    required this.content,
    required this.createdAt,
    this.metadata = const {},
  });

  @override
  String toString() => 'MemoryRecord($id: "$content")';
}
