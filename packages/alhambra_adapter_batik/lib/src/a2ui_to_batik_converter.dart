import 'package:batik/batik.dart' as batik;
import 'package:alhambra_ui/alhambra_ui.dart' as a2ui;

/// Converts an Alhambra [a2ui.UiSurface] into a Batik [batik.AgentUIResponse]
/// so Batik's renderer can materialise it into Flutter widgets.
///
/// Mapping strategy uses Batik's exact constructor signatures:
/// ```
/// a2ui.TextNode         → batik.TextNode(text, variant)
/// a2ui.HeadingNode      → batik.TextNode(text, variant: 'h{level}')
/// a2ui.ButtonNode       → batik.ButtonNode(label, variant, actions)
/// a2ui.CardNode         → batik.CardNode(children)  — no 'title' field
/// a2ui.ContainerNode    → batik.RowNode / batik.ColumnNode
/// a2ui.TableNode        → batik.ColumnNode of RowNodes
/// a2ui.MarkdownNode     → batik.MarkdownNode(content)
/// a2ui.ListNode         → batik.ListNode(children)
/// a2ui.BadgeNode        → batik.BadgeNode(label, backgroundColor)
/// a2ui.DividerNode      → batik.DividerNode()
/// a2ui.MetadataRowNode  → batik.RowNode([label, value])
/// a2ui.ChartNode        → batik.ChartNode(chartType, data, title)
/// a2ui.ArtifactNode     → batik.CardNode with TextNode children
/// a2ui.ProvenanceNode   → batik.TextNode(citation + confidence)
/// a2ui.ImageNode        → batik.ImageNode(src, alt)
/// ```
abstract final class A2UiToBatikConverter {
  static batik.AgentUIResponse convert(a2ui.UiSurface surface) =>
      batik.AgentUIResponse(
        schemaVersion: '1.0.0',
        root: _convertNode(surface.rootNode),
        metadata: {
          'a2ui_surface_id': surface.id,
          'a2ui_surface_title': surface.title,
          ...surface.metadata,
        },
      );

  static batik.UINode _convertNode(a2ui.UiNode node) => switch (node) {
        a2ui.TextNode(:final text, :final isSecondary) => batik.TextNode(
            id: node.id,
            text: text,
            variant: isSecondary ? 'bodySmall' : 'bodyMedium',
          ),
        a2ui.HeadingNode(:final text, :final level) => batik.TextNode(
            id: node.id,
            text: text,
            variant: 'h$level',
          ),
        a2ui.ButtonNode(:final label, :final action, :final isPrimary) =>
          batik.ButtonNode(
            id: node.id,
            label: label,
            variant: isPrimary ? 'filled' : 'outlined',
            actions: {'onTap': _convertAction(action)},
          ),
        // Batik CardNode has no 'title' — prepend a heading TextNode if present.
        a2ui.CardNode(:final title, :final children) => batik.CardNode(
            id: node.id,
            children: [
              if (title != null)
                batik.TextNode(text: title, variant: 'titleMedium'),
              ...children.map(_convertNode),
            ],
          ),
        a2ui.ContainerNode(:final children, :final isRow) => isRow
            ? batik.RowNode(
                id: node.id,
                children: children.map(_convertNode).toList(),
              )
            : batik.ColumnNode(
                id: node.id,
                children: children.map(_convertNode).toList(),
              ),
        // Table → Column of Rows: header row + data rows
        a2ui.TableNode(:final headers, :final rows) => batik.ColumnNode(
            id: node.id,
            children: [
              batik.RowNode(
                children: headers
                    .map((h) =>
                        batik.TextNode(text: h, variant: 'labelMedium'))
                    .toList(),
              ),
              ...rows.map(
                (r) => batik.RowNode(
                  children: r
                      .map((c) => batik.TextNode(text: c))
                      .toList(),
                ),
              ),
            ],
          ),
        a2ui.MarkdownNode(:final markdown) =>
          batik.MarkdownNode(id: node.id, content: markdown),
        // Batik ListNode has no 'ordered' — use children
        a2ui.ListNode(:final items) => batik.ListNode(
            id: node.id,
            children: items.map(_convertNode).toList(),
          ),
        // BadgeNode: map semantic variant → hex color approximation
        a2ui.BadgeNode(:final label, :final variant) => batik.BadgeNode(
            id: node.id,
            label: label,
            backgroundColor: _variantToColor(variant),
          ),
        a2ui.DividerNode() => batik.DividerNode(id: node.id),
        a2ui.MetadataRowNode(:final label, :final value) => batik.RowNode(
            id: node.id,
            children: [
              batik.TextNode(text: label, variant: 'labelSmall'),
              batik.TextNode(text: value, variant: 'bodySmall'),
            ],
          ),
        // ChartNode: wrap labels+series into Batik's data Map
        a2ui.ChartNode(:final title, :final chartType, :final labels, :final series) =>
          batik.ChartNode(
            id: node.id,
            chartType: chartType,
            title: title.isEmpty ? null : title,
            data: {
              'labels': labels,
              'series': series,
            },
          ),
        // ArtifactNode → Card with id/title/hint as text rows
        a2ui.ArtifactNode(:final artifactId, :final title, :final displayHint) =>
          batik.CardNode(
            id: node.id ?? artifactId,
            children: [
              batik.TextNode(text: title, variant: 'titleSmall'),
              batik.TextNode(
                  text: 'ID: $artifactId  [$displayHint]',
                  variant: 'bodySmall'),
            ],
          ),
        a2ui.ProvenanceNode(:final citation, :final confidence) =>
          batik.TextNode(
            id: node.id,
            text: confidence != null
                ? '$citation (${(confidence * 100).round()}%)'
                : citation,
            variant: 'bodySmall',
          ),
        a2ui.ImageNode(:final url, :final altText) => batik.ImageNode(
            id: node.id,
            src: url,
            alt: altText,
            fit: 'contain',
          ),
      };

  static batik.UIAction _convertAction(a2ui.UiAction action) =>
      switch (action) {
        a2ui.NavigateAction(:final route) =>
          batik.UIAction(type: 'navigate', payload: {'route': route}),
        a2ui.SubmitAction(:final target, :final payload) => batik.UIAction(
            type: 'submitForm',
            payload: {'target': target, ...payload},
          ),
        a2ui.InvokeAction(:final command, :final parameters) => batik.UIAction(
            type: 'custom',
            payload: {'command': command, ...parameters},
          ),
        a2ui.RefreshAction() =>
          batik.UIAction(type: 'custom', payload: {'command': 'refresh'}),
        a2ui.ApproveAction(:final resourceId) => batik.UIAction(
            type: 'custom',
            payload: {'command': 'approve', 'resourceId': resourceId},
          ),
        a2ui.RejectAction(:final resourceId, :final reason) => batik.UIAction(
            type: 'custom',
            payload: {
              'command': 'reject',
              'resourceId': resourceId,
              if (reason != null) 'reason': reason,
            },
          ),
      };

  /// Maps A2UI semantic variant to a hex color hint for Batik's BadgeNode.
  static String? _variantToColor(String variant) => switch (variant) {
        'success' => '#2E7D32',
        'warning' => '#E65100',
        'error' => '#C62828',
        'info' => '#1565C0',
        _ => null, // neutral — let Batik use default
      };
}
