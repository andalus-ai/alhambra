/// A typed reference pointing to an entity in the provenance graph.
final class ProvenanceRef {
  final String type;
  final String id;

  const ProvenanceRef({
    required this.type,
    required this.id,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProvenanceRef && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);

  @override
  String toString() => '$type:$id';
}
