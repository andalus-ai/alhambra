import 'package:batik/batik.dart' as batik;
import 'package:alhambra_ui/alhambra_ui.dart' as a2ui;

/// Converts a Batik [batik.AgentUIResponse] into an Alhambra [a2ui.UiSurface].
///
/// Use this when any Batik adapter (AndalusAdapter, OpenAIAdapter,
/// AnthropicAdapter, MockAdapter) produces a response and you want to render it
/// through Alhambra's [a2ui.UiSurfaceView] with A2UI guards applied.
abstract final class BatikToA2UiConverter {
  static a2ui.UiSurface convert(
    batik.AgentUIResponse response, {
    String? surfaceId,
    String? title,
  }) =>
      a2ui.UiSurface(
        id: surfaceId ??
            response.sessionId ??
            'batik-${response.turnId ?? 'surface'}',
        title: title ??
            (response.metadata['title'] as String? ?? 'Agent Response'),
        rootNode: _convertNode(response.root),
        metadata: Map<String, Object?>.from(response.metadata),
      );

  static a2ui.UiNode _convertNode(batik.UINode node) {
    final children = node.children.map(_convertNode).toList();
    final onTap = node.actions['onTap'];

    return switch (node.type) {
      'text' => () {
          final n = node as batik.TextNode;
          final v = n.variant ?? '';
          if (RegExp(r'^h[1-6]$').hasMatch(v)) {
            return a2ui.HeadingNode(
              n.text,
              level: int.tryParse(v.substring(1)) ?? 1,
              id: n.id,
            );
          }
          return a2ui.TextNode(
            n.text,
            id: n.id,
            isSecondary: v == 'bodySmall' || v == 'labelSmall' ||
                v == 'caption' || v == 'secondary',
          );
        }(),
      'richText' => a2ui.TextNode('[richText]', id: node.id, isSecondary: true),
      'button' => () {
          final n = node as batik.ButtonNode;
          return a2ui.ButtonNode(
            id: n.id,
            label: n.label ?? '',
            action: onTap != null
                ? _convertAction(onTap)
                : const a2ui.RefreshAction(),
            isPrimary: n.variant == null ||
                n.variant == 'filled' ||
                n.variant == 'elevated',
          );
        }(),
      'card' => a2ui.CardNode(id: node.id, children: children),
      'row' => a2ui.ContainerNode(id: node.id, children: children, isRow: true),
      'column' || 'container' =>
        a2ui.ContainerNode(id: node.id, children: children),
      'list' => a2ui.ListNode(id: node.id, items: children),
      'listItem' =>
        a2ui.ContainerNode(id: node.id, children: children),
      'markdown' => () {
          final n = node as batik.MarkdownNode;
          return a2ui.MarkdownNode(n.content, id: n.id);
        }(),
      'divider' => a2ui.DividerNode(id: node.id),
      'badge' => () {
          final n = node as batik.BadgeNode;
          return a2ui.BadgeNode(
            id: n.id,
            label: n.label ?? '',
            variant: _colorToVariant(n.backgroundColor),
          );
        }(),
      'chip' => a2ui.BadgeNode(
          id: node.id,
          label: (node as dynamic).label as String? ?? '',
        ),
      'image' => () {
          final n = node as batik.ImageNode;
          return a2ui.ImageNode(
            id: n.id,
            url: n.src,
            altText: n.alt ?? '',
          );
        }(),
      'chart' => () {
          final n = node as batik.ChartNode;
          final data = n.data;
          return a2ui.ChartNode(
            id: n.id,
            title: n.title ?? '',
            chartType: n.chartType,
            labels: _extractLabels(data),
            series: _extractSeries(data),
          );
        }(),
      'progressBar' || 'spacer' || 'icon' =>
        a2ui.DividerNode(id: node.id),
      // Fallback: unknown Batik node → secondary TextNode
      _ => a2ui.TextNode('[${node.type}]', id: node.id, isSecondary: true),
    };
  }

  static a2ui.UiAction _convertAction(batik.UIAction action) =>
      switch (action.type) {
        'navigate' =>
          a2ui.NavigateAction(action.payload['route'] as String? ?? '/'),
        'submitForm' => a2ui.SubmitAction(
            target: action.payload['target'] as String? ?? '',
            payload: Map<String, Object?>.from(action.payload)
              ..remove('target'),
          ),
        'custom' => () {
            final cmd = action.payload['command'] as String?;
            if (cmd == null || cmd == 'refresh') return const a2ui.RefreshAction();
            if (cmd == 'approve') {
              return a2ui.ApproveAction(
                  action.payload['resourceId'] as String? ?? '');
            }
            if (cmd == 'reject') {
              return a2ui.RejectAction(
                action.payload['resourceId'] as String? ?? '',
                reason: action.payload['reason'] as String?,
              );
            }
            return a2ui.InvokeAction(
              command: cmd,
              parameters: Map<String, Object?>.from(action.payload)
                ..remove('command'),
            );
          }(),
        _ => const a2ui.RefreshAction(),
      };

  static String _colorToVariant(String? backgroundColor) {
    if (backgroundColor == null) return 'neutral';
    return switch (backgroundColor.toLowerCase()) {
      '#2e7d32' || 'green' => 'success',
      '#e65100' || 'orange' => 'warning',
      '#c62828' || 'red' => 'error',
      '#1565c0' || 'blue' => 'info',
      _ => 'neutral',
    };
  }

  static List<String> _extractLabels(Map<String, dynamic> data) {
    final raw = data['labels'];
    if (raw is List) return raw.whereType<String>().toList();
    return [];
  }

  static List<Map<String, Object?>> _extractSeries(Map<String, dynamic> data) {
    final raw = data['series'];
    if (raw is List) {
      return raw.whereType<Map>().map((m) => m.cast<String, Object?>()).toList();
    }
    return [];
  }
}
