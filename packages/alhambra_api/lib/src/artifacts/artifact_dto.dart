/// DTO representation of an intelligence artifact.
final class IntelligenceArtifactDto {
  final String id;
  final String type;
  final String title;
  final String? description;
  final Object? data;
  final List<String> evidenceIds;
  final String epistemicClass;
  final String? semanticType;
  final DateTime createdAt;

  const IntelligenceArtifactDto({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    this.data,
    this.evidenceIds = const [],
    required this.epistemicClass,
    this.semanticType,
    required this.createdAt,
  });

  @override
  String toString() => 'IntelligenceArtifactDto($id: "$title" [$type, $epistemicClass])';
}

/// Filter criteria for listing artifacts.
final class ArtifactListRequest {
  final String? executionId;
  final String? type;
  final String? epistemicClass;
  final int page;
  final int pageSize;

  const ArtifactListRequest({
    this.executionId,
    this.type,
    this.epistemicClass,
    this.page = 0,
    this.pageSize = 20,
  });
}
