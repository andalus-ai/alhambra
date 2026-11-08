import 'ui_node.dart';
import 'ui_surface.dart';

/// Bridges an [IntelligenceResult]-shaped map to a [UiSurface] for rendering.
///
/// This is the P14 connecting layer:
/// ```
/// IntelligenceResult → IntelligenceResultSurface.from() → UiSurface → renderer
/// ```
///
/// The bridge reads [summary], [artifacts], [evidence], [warnings] from the
/// result and builds a standardised surface with appropriate node types.
///
/// It does NOT access the network, file system, or any services — it only
/// maps data to the declarative node tree.
abstract final class IntelligenceResultSurface {
  /// Builds a [UiSurface] from a completed intelligence result's key fields.
  ///
  /// Parameters mirror [IntelligenceResult] to avoid a direct package dependency:
  /// `alhambra_ui` must not depend on `alhambra_intelligence`.
  static UiSurface from({
    required String surfaceId,
    required String title,
    required bool success,
    String? summary,
    List<ArtifactSummary> artifacts = const [],
    List<EvidenceSummary> evidence = const [],
    List<String> warnings = const [],
    String? errorMessage,
  }) {
    final nodes = <UiNode>[];

    // Status badge
    nodes.add(BadgeNode(
      label: success ? 'Completed' : 'Failed',
      variant: success ? 'success' : 'error',
    ));

    // Summary
    if (summary != null && summary.isNotEmpty) {
      nodes.add(const DividerNode());
      nodes.add(HeadingNode('Summary', level: 3));
      nodes.add(MarkdownNode(summary));
    }

    // Error
    if (!success && errorMessage != null) {
      nodes.add(const DividerNode());
      nodes.add(BadgeNode(label: 'Error', variant: 'error'));
      nodes.add(TextNode(errorMessage, isSecondary: true));
    }

    // Warnings
    if (warnings.isNotEmpty) {
      nodes.add(const DividerNode());
      nodes.add(HeadingNode('Warnings', level: 4));
      nodes.add(ListNode(
        items: warnings.map((w) => TextNode(w, isSecondary: true)).toList(),
      ));
    }

    // Artifacts
    if (artifacts.isNotEmpty) {
      nodes.add(const DividerNode());
      nodes.add(HeadingNode('Outputs', level: 3));
      for (final a in artifacts) {
        nodes.add(ArtifactNode(
          artifactId: a.id,
          title: a.title,
          displayHint: a.displayHint,
        ));
      }
    }

    // Evidence
    if (evidence.isNotEmpty) {
      nodes.add(const DividerNode());
      nodes.add(HeadingNode('Evidence', level: 3));
      for (final e in evidence) {
        nodes.add(ProvenanceNode(
          evidenceId: e.id,
          citation: e.citation,
          confidence: e.confidence,
        ));
      }
    }

    return UiSurface(
      id: surfaceId,
      title: title,
      rootNode: ContainerNode(children: nodes),
      metadata: {'success': success, 'artifactCount': artifacts.length},
    );
  }
}

/// Lightweight summary of an artifact for surface construction.
///
/// Mirrors [IntelligenceArtifact] fields without importing the intelligence package.
final class ArtifactSummary {
  final String id;
  final String title;
  final String displayHint;

  const ArtifactSummary({
    required this.id,
    required this.title,
    this.displayHint = 'auto',
  });
}

/// Lightweight summary of an evidence item for surface construction.
final class EvidenceSummary {
  final String id;
  final String citation;
  final double? confidence;

  const EvidenceSummary({
    required this.id,
    required this.citation,
    this.confidence,
  });
}
