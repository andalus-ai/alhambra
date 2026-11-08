import 'package:alhambra_core/alhambra_core.dart';
import 'confidence.dart';
import 'evidence_type.dart';

/// A first-class piece of evidence supporting findings, artifacts, and decisions.
final class Evidence {
  final EvidenceId id;
  final EvidenceType type;
  final String source;
  final String reference;
  final String? description;
  final Confidence? confidence;
  final Map<String, Object?> metadata;

  const Evidence({
    required this.id,
    required this.type,
    required this.source,
    required this.reference,
    this.description,
    this.confidence,
    this.metadata = const {},
  });

  @override
  String toString() =>
      'Evidence($id: $type from "$source" ref: "$reference")';
}
