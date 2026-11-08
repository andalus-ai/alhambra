/// DTO representation of an evidence item.
final class EvidenceDto {
  final String id;
  final String type;
  final String source;
  final String reference;
  final String? description;
  final double? confidence;
  final Map<String, Object?> metadata;

  const EvidenceDto({
    required this.id,
    required this.type,
    required this.source,
    required this.reference,
    this.description,
    this.confidence,
    this.metadata = const {},
  });

  @override
  String toString() => 'EvidenceDto($id: $type from "$source")';
}

/// Filter criteria for querying evidence items.
final class EvidenceListRequest {
  final String? type;
  final String? source;
  final int page;
  final int pageSize;

  const EvidenceListRequest({
    this.type,
    this.source,
    this.page = 0,
    this.pageSize = 20,
  });
}
