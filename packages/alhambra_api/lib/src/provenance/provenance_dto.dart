/// DTO pointing to a node in the provenance graph.
final class ProvenanceRefDto {
  final String type;
  final String id;

  const ProvenanceRefDto({
    required this.type,
    required this.id,
  });

  @override
  String toString() => '$type:$id';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProvenanceRefDto &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          id == other.id;

  @override
  int get hashCode => Object.hash(type, id);
}

/// DTO representing a relationship link in the provenance graph.
final class ProvenanceLinkDto {
  final ProvenanceRefDto from;
  final String relation;
  final ProvenanceRefDto to;

  const ProvenanceLinkDto({
    required this.from,
    required this.relation,
    required this.to,
  });

  @override
  String toString() => '$from --$relation--> $to';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProvenanceLinkDto &&
          runtimeType == other.runtimeType &&
          from == other.from &&
          relation == other.relation &&
          to == other.to;

  @override
  int get hashCode => Object.hash(from, relation, to);
}

/// DTO representing the entire provenance graph for an artifact or execution.
final class ProvenanceGraphDto {
  final List<ProvenanceLinkDto> links;

  const ProvenanceGraphDto({
    this.links = const [],
  });

  /// Returns all links where [from.id] matches the given [id].
  List<ProvenanceLinkDto> getLinksFrom(String id) =>
      links.where((l) => l.from.id == id).toList();

  /// Returns all links where [to.id] matches the given [id].
  List<ProvenanceLinkDto> getLinksTo(String id) =>
      links.where((l) => l.to.id == id).toList();

  @override
  String toString() => 'ProvenanceGraphDto(links: ${links.length})';
}
