import 'dart:convert';

import 'ui_action.dart';
import 'ui_node.dart';
import 'ui_surface.dart';

/// Serializes a [UiSurface] to a JSON map and deserializes back.
///
/// This is the transport contract between the agent (Andalus) and the UI:
/// ```
/// Andalus produces JSON → A2UiCodec.fromJson() → UiSurface → renderer → Flutter
/// ```
///
/// Node types are tagged with a `_type` discriminator field.
/// Unknown types degrade gracefully to [TextNode] with a fallback message.
abstract final class A2UiCodec {
  // ── Encode ─────────────────────────────────────────────────────────────────

  /// Serializes [surface] to a JSON-compatible map.
  static Map<String, Object?> encode(UiSurface surface) => {
        'id': surface.id,
        'title': surface.title,
        'rootNode': _encodeNode(surface.rootNode),
        'metadata': surface.metadata,
      };

  /// Serializes [surface] to a JSON string.
  static String toJson(UiSurface surface) => jsonEncode(encode(surface));

  // ── Decode ─────────────────────────────────────────────────────────────────

  /// Deserializes a [UiSurface] from a JSON-compatible map.
  static UiSurface decode(Map<String, Object?> json) => UiSurface(
        id: json['id'] as String,
        title: json['title'] as String,
        rootNode: _decodeNode(json['rootNode'] as Map<String, Object?>),
        metadata: (json['metadata'] as Map?)?.cast<String, Object?>() ?? {},
      );

  /// Deserializes a [UiSurface] from a JSON string.
  static UiSurface fromJson(String raw) =>
      decode(jsonDecode(raw) as Map<String, Object?>);

  // ── Node encoding ──────────────────────────────────────────────────────────

  static Map<String, Object?> _encodeNode(UiNode node) => switch (node) {
        TextNode(:final text, :final isSecondary) => {
            '_type': 'text',
            'text': text,
            'secondary': isSecondary,
            if (node.id != null) 'id': node.id,
          },
        HeadingNode(:final text, :final level) => {
            '_type': 'heading',
            'text': text,
            'level': level,
            if (node.id != null) 'id': node.id,
          },
        ButtonNode(:final label, :final action, :final isPrimary) => {
            '_type': 'button',
            'label': label,
            'action': _encodeAction(action),
            'primary': isPrimary,
            if (node.id != null) 'id': node.id,
          },
        CardNode(:final title, :final children) => {
            '_type': 'card',
            if (title != null) 'title': title,
            'children': children.map(_encodeNode).toList(),
            if (node.id != null) 'id': node.id,
          },
        ContainerNode(:final children, :final isRow) => {
            '_type': 'container',
            'children': children.map(_encodeNode).toList(),
            'row': isRow,
            if (node.id != null) 'id': node.id,
          },
        TableNode(:final headers, :final rows) => {
            '_type': 'table',
            'headers': headers,
            'rows': rows,
            if (node.id != null) 'id': node.id,
          },
        // P14 nodes
        MarkdownNode(:final markdown) => {
            '_type': 'markdown',
            'markdown': markdown,
            if (node.id != null) 'id': node.id,
          },
        ListNode(:final items, :final ordered) => {
            '_type': 'list',
            'items': items.map(_encodeNode).toList(),
            'ordered': ordered,
            if (node.id != null) 'id': node.id,
          },
        BadgeNode(:final label, :final variant) => {
            '_type': 'badge',
            'label': label,
            'variant': variant,
            if (node.id != null) 'id': node.id,
          },
        DividerNode() => {'_type': 'divider', if (node.id != null) 'id': node.id},
        MetadataRowNode(:final label, :final value) => {
            '_type': 'metadata_row',
            'label': label,
            'value': value,
            if (node.id != null) 'id': node.id,
          },
        ChartNode(:final title, :final chartType, :final labels, :final series) => {
            '_type': 'chart',
            'title': title,
            'chartType': chartType,
            'labels': labels,
            'series': series,
            if (node.id != null) 'id': node.id,
          },
        ArtifactNode(:final artifactId, :final title, :final displayHint) => {
            '_type': 'artifact',
            'artifactId': artifactId,
            'title': title,
            'displayHint': displayHint,
            if (node.id != null) 'id': node.id,
          },
        ProvenanceNode(:final evidenceId, :final citation, :final confidence) => {
            '_type': 'provenance',
            'evidenceId': evidenceId,
            'citation': citation,
            if (confidence != null) 'confidence': confidence,
            if (node.id != null) 'id': node.id,
          },
        ImageNode(:final url, :final altText, :final maxHeight) => {
            '_type': 'image',
            'url': url,
            'altText': altText,
            if (maxHeight != null) 'maxHeight': maxHeight,
            if (node.id != null) 'id': node.id,
          },
      };

  // ── Node decoding ──────────────────────────────────────────────────────────

  static UiNode _decodeNode(Map<String, Object?> json) {
    final type = json['_type'] as String? ?? 'text';
    final id = json['id'] as String?;

    return switch (type) {
      'text' => TextNode(
          json['text'] as String? ?? '',
          id: id,
          isSecondary: json['secondary'] as bool? ?? false,
        ),
      'heading' => HeadingNode(
          json['text'] as String? ?? '',
          id: id,
          level: json['level'] as int? ?? 1,
        ),
      'button' => ButtonNode(
          id: id,
          label: json['label'] as String? ?? '',
          action: _decodeAction(json['action'] as Map<String, Object?>? ?? {}),
          isPrimary: json['primary'] as bool? ?? true,
        ),
      'card' => CardNode(
          id: id,
          title: json['title'] as String?,
          children: _decodeChildren(json['children']),
        ),
      'container' => ContainerNode(
          id: id,
          children: _decodeChildren(json['children']),
          isRow: json['row'] as bool? ?? false,
        ),
      'table' => TableNode(
          id: id,
          headers: _castList<String>(json['headers']),
          rows: (json['rows'] as List?)
                  ?.map((r) => _castList<String>(r))
                  .toList() ??
              [],
        ),
      'markdown' => MarkdownNode(json['markdown'] as String? ?? '', id: id),
      'list' => ListNode(
          id: id,
          items: _decodeChildren(json['items']),
          ordered: json['ordered'] as bool? ?? false,
        ),
      'badge' => BadgeNode(
          id: id,
          label: json['label'] as String? ?? '',
          variant: json['variant'] as String? ?? 'neutral',
        ),
      'divider' => DividerNode(id: id),
      'metadata_row' => MetadataRowNode(
          id: id,
          label: json['label'] as String? ?? '',
          value: json['value'] as String? ?? '',
        ),
      'chart' => ChartNode(
          id: id,
          title: json['title'] as String? ?? '',
          chartType: json['chartType'] as String? ?? 'bar',
          labels: _castList<String>(json['labels']),
          series: (json['series'] as List?)
                  ?.map((s) => (s as Map).cast<String, Object?>())
                  .toList() ??
              [],
        ),
      'artifact' => ArtifactNode(
          id: id,
          artifactId: json['artifactId'] as String? ?? '',
          title: json['title'] as String? ?? '',
          displayHint: json['displayHint'] as String? ?? 'auto',
        ),
      'provenance' => ProvenanceNode(
          id: id,
          evidenceId: json['evidenceId'] as String? ?? '',
          citation: json['citation'] as String? ?? '',
          confidence: (json['confidence'] as num?)?.toDouble(),
        ),
      'image' => ImageNode(
          id: id,
          url: json['url'] as String? ?? '',
          altText: json['altText'] as String? ?? '',
          maxHeight: (json['maxHeight'] as num?)?.toDouble(),
        ),
      // Graceful degradation for unknown node types
      _ => TextNode('[Unknown node type: $type]', id: id, isSecondary: true),
    };
  }

  // ── Action encoding/decoding ───────────────────────────────────────────────

  static Map<String, Object?> _encodeAction(UiAction action) => switch (action) {
        NavigateAction(:final route) => {'_type': 'navigate', 'route': route},
        SubmitAction(:final target, :final payload) => {
            '_type': 'submit',
            'target': target,
            'payload': payload,
          },
        InvokeAction(:final command, :final parameters) => {
            '_type': 'invoke',
            'command': command,
            'parameters': parameters,
          },
        RefreshAction() => {'_type': 'refresh'},
        ApproveAction(:final resourceId) => {
            '_type': 'approve',
            'resourceId': resourceId,
          },
        RejectAction(:final resourceId, :final reason) => {
            '_type': 'reject',
            'resourceId': resourceId,
            if (reason != null) 'reason': reason,
          },
      };

  static UiAction _decodeAction(Map<String, Object?> json) {
    final type = json['_type'] as String? ?? 'refresh';
    return switch (type) {
      'navigate' => NavigateAction(json['route'] as String? ?? '/'),
      'submit' => SubmitAction(
          target: json['target'] as String? ?? '',
          payload: (json['payload'] as Map?)?.cast<String, Object?>() ?? {},
        ),
      'invoke' => InvokeAction(
          command: json['command'] as String? ?? '',
          parameters:
              (json['parameters'] as Map?)?.cast<String, Object?>() ?? {},
        ),
      'approve' => ApproveAction(json['resourceId'] as String? ?? ''),
      'reject' => RejectAction(
          json['resourceId'] as String? ?? '',
          reason: json['reason'] as String?,
        ),
      _ => const RefreshAction(),
    };
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static List<UiNode> _decodeChildren(Object? raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((m) => _decodeNode(m.cast<String, Object?>()))
        .toList();
  }

  static List<T> _castList<T>(Object? raw) {
    if (raw is! List) return [];
    return raw.whereType<T>().toList();
  }
}
