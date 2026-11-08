import 'ui_action.dart';

/// Sealed hierarchy of declarative UI nodes for dynamic rendering and A2UI protocol.
///
/// P13 base nodes: TextNode, HeadingNode, ButtonNode, CardNode, ContainerNode, TableNode.
/// P14 extended nodes: MarkdownNode, ListNode, BadgeNode, DividerNode, MetadataRowNode,
///                     ChartNode, ArtifactNode, ProvenanceNode, ImageNode.
///
/// Design rule: all nodes are pure data — no Flutter, no callbacks, no platform handles.
/// Agents specify WHAT to show; the renderer decides HOW IT LOOKS.
sealed class UiNode {
  final String? id;
  const UiNode({this.id});
}

// ── P13 Base Nodes ────────────────────────────────────────────────────────────

/// A text node.
final class TextNode extends UiNode {
  final String text;
  final bool isSecondary;

  const TextNode(this.text, {super.id, this.isSecondary = false});
}

/// A heading node.
final class HeadingNode extends UiNode {
  final String text;
  final int level; // 1 to 6

  const HeadingNode(this.text, {super.id, this.level = 1});
}

/// A button node with an associated [UiAction].
final class ButtonNode extends UiNode {
  final String label;
  final UiAction action;
  final bool isPrimary;

  const ButtonNode({
    super.id,
    required this.label,
    required this.action,
    this.isPrimary = true,
  });
}

/// A card container node.
final class CardNode extends UiNode {
  final String? title;
  final List<UiNode> children;

  const CardNode({
    super.id,
    this.title,
    required this.children,
  });
}

/// A container node with layout direction.
final class ContainerNode extends UiNode {
  final List<UiNode> children;
  final bool isRow;

  const ContainerNode({
    super.id,
    required this.children,
    this.isRow = false,
  });
}

/// A table node.
final class TableNode extends UiNode {
  final List<String> headers;
  final List<List<String>> rows;

  const TableNode({
    super.id,
    required this.headers,
    required this.rows,
  });
}

// ── P14 Extended Nodes ────────────────────────────────────────────────────────

/// Inline markdown text. The renderer is responsible for safe rendering.
/// Agents cannot inject HTML — markdown only.
final class MarkdownNode extends UiNode {
  final String markdown;
  const MarkdownNode(this.markdown, {super.id});
}

/// Ordered or unordered list of child [UiNode] items.
final class ListNode extends UiNode {
  final List<UiNode> items;
  final bool ordered;
  const ListNode({super.id, required this.items, this.ordered = false});
}

/// Visual status/label badge.
///
/// [variant] semantic hint: 'success' | 'warning' | 'error' | 'info' | 'neutral'.
/// Renderer maps variant to theme colours — agents cannot specify hex colours.
final class BadgeNode extends UiNode {
  final String label;
  final String variant;
  const BadgeNode({super.id, required this.label, this.variant = 'neutral'});
}

/// Horizontal visual separator.
final class DividerNode extends UiNode {
  const DividerNode({super.id});
}

/// A single key–value metadata row.
final class MetadataRowNode extends UiNode {
  final String label;
  final String value;
  const MetadataRowNode({super.id, required this.label, required this.value});
}

/// Chart specification. Renderer chooses the charting library.
///
/// [chartType]: 'bar' | 'line' | 'pie' | 'scatter'.
/// [series]: list of `{'label': String, 'values': List<num>}` maps.
final class ChartNode extends UiNode {
  final String title;
  final String chartType;
  final List<String> labels;
  final List<Map<String, Object?>> series;
  const ChartNode({
    super.id,
    required this.title,
    required this.chartType,
    required this.labels,
    required this.series,
  });
}

/// Reference to an [IntelligenceArtifact] by id for inline rendering.
///
/// [displayHint]: 'table' | 'text' | 'chart' | 'file' | 'auto'.
/// The renderer resolves the artifact from the current execution result context.
final class ArtifactNode extends UiNode {
  final String artifactId;
  final String title;
  final String displayHint;
  const ArtifactNode({
    super.id,
    required this.artifactId,
    required this.title,
    this.displayHint = 'auto',
  });
}

/// Evidence / provenance citation produced by an agent.
final class ProvenanceNode extends UiNode {
  final String evidenceId;
  final String citation;

  /// Confidence in [0.0, 1.0]; null means unspecified.
  final double? confidence;
  const ProvenanceNode({
    super.id,
    required this.evidenceId,
    required this.citation,
    this.confidence,
  });
}

/// Safe image — HTTPS URLs only, no data-URIs, no inline scripts.
final class ImageNode extends UiNode {
  final String url;
  final String altText;
  final double? maxHeight;
  const ImageNode({
    super.id,
    required this.url,
    required this.altText,
    this.maxHeight,
  });
}
