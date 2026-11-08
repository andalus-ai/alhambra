/// Immutable metadata reference pointing to a persisted file asset.
final class FileReference {
  final String id;
  final String name;
  final String contentType;
  final int size;

  const FileReference({
    required this.id,
    required this.name,
    required this.contentType,
    required this.size,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileReference &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FileReference(id: $id, name: $name, size: $size)';
}
