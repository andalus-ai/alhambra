/// Query for searching remembered records.
final class MemoryQuery {
  final String text;
  final String? executionId;
  final String? userId;
  final int limit;

  const MemoryQuery({
    required this.text,
    this.executionId,
    this.userId,
    this.limit = 10,
  });

  @override
  String toString() => 'MemoryQuery("$text", user: $userId)';
}
