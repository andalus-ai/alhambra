import 'epistemic_class.dart';

/// Metadata accompanying an [IntelligenceArtifact].
final class ArtifactMetadata {
  final EpistemicClass epistemicClass;
  final String? semanticType;
  final String? createdBy;
  final DateTime createdAt;
  final Map<String, Object?> custom;

  const ArtifactMetadata({
    this.epistemicClass = EpistemicClass.inferred,
    this.semanticType,
    this.createdBy,
    required this.createdAt,
    this.custom = const {},
  });

  @override
  String toString() =>
      'ArtifactMetadata($epistemicClass, semantic: $semanticType, by: $createdBy)';
}
