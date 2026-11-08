import 'package:flutter/material.dart';

import '../components/buttons/alhambra_button.dart';
import '../components/cards/alhambra_card.dart';
import '../components/tables/alhambra_data_table.dart';
import '../theme/spacing.dart';
import 'a2ui_action_guard.dart';
import 'ui_action.dart';
import 'ui_node.dart';
import 'ui_surface.dart';

/// Contract for converting declarative [UiNode] structures into Flutter widgets.
abstract interface class UiNodeRenderer {
  Widget render(
    BuildContext context,
    UiNode node, {
    void Function(UiAction action)? onAction,
  });
}

/// Standard [UiNodeRenderer] — renders all P13 + P14 node types using
/// Alhambra UI components.
///
/// P14 nodes (MarkdownNode, ChartNode, etc.) have placeholder renderers that
/// display content accurately while remaining overridable by product teams.
final class DefaultUiNodeRenderer implements UiNodeRenderer {
  const DefaultUiNodeRenderer();

  @override
  Widget render(
    BuildContext context,
    UiNode node, {
    void Function(UiAction action)? onAction,
  }) {
    return switch (node) {
      // ── P13 Base Nodes ────────────────────────────────────────────────────
      TextNode(:final text, :final isSecondary) => Text(
          text,
          style: isSecondary
              ? Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )
              : Theme.of(context).textTheme.bodyMedium,
        ),
      HeadingNode(:final text, :final level) => Text(
          text,
          style: switch (level) {
            1 => Theme.of(context).textTheme.headlineMedium,
            2 => Theme.of(context).textTheme.titleLarge,
            _ => Theme.of(context).textTheme.titleMedium,
          },
        ),
      ButtonNode(:final label, :final action, :final isPrimary) => AlhambraButton(
          variant: isPrimary
              ? AlhambraButtonVariant.primary
              : AlhambraButtonVariant.secondary,
          onPressed: onAction != null ? () => onAction(action) : null,
          child: Text(label),
        ),
      CardNode(:final title, :final children) => AlhambraCard(
          header: title != null
              ? Text(title, style: Theme.of(context).textTheme.titleMedium)
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children
                .map((child) => render(context, child, onAction: onAction))
                .toList(),
          ),
        ),
      ContainerNode(:final children, :final isRow) => isRow
          ? Row(
              children: children
                  .map((child) => render(context, child, onAction: onAction))
                  .toList(),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children
                  .map(
                    (child) => Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AlhambraSpacing.xs,
                      ),
                      child: render(context, child, onAction: onAction),
                    ),
                  )
                  .toList(),
            ),
      TableNode(:final headers, :final rows) =>
        AlhambraDataTable<List<String>>(
          items: rows,
          columns: headers
              .asMap()
              .entries
              .map(
                (e) => AlhambraDataColumn<List<String>>(
                  label: e.value,
                  cellBuilder: (row) => Text(row[e.key]),
                ),
              )
              .toList(),
        ),

      // ── P14 Extended Nodes ────────────────────────────────────────────────
      MarkdownNode(:final markdown) => SelectableText(
          markdown,
          style: Theme.of(context).textTheme.bodyMedium,
        ),

      ListNode(:final items, :final ordered) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.indexed
              .map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                        child: Text(
                          ordered ? '${entry.$1 + 1}.' : '•',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Expanded(
                        child: render(context, entry.$2, onAction: onAction),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),

      BadgeNode(:final label, :final variant) => _BadgeWidget(
          label: label,
          variant: variant,
        ),

      DividerNode() => const Divider(height: 24),

      MetadataRowNode(:final label, :final value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),

      ChartNode(:final title, :final chartType) => AlhambraCard(
          header: Text(title, style: Theme.of(context).textTheme.titleSmall),
          child: Padding(
            padding: const EdgeInsets.all(AlhambraSpacing.md),
            child: Text(
              '[$chartType chart — connect a charting library to render]',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
        ),

      ArtifactNode(:final artifactId, :final title, :final displayHint) =>
        AlhambraCard(
          header: Row(
            children: [
              const Icon(Icons.description_outlined, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              _BadgeWidget(label: displayHint, variant: 'info'),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AlhambraSpacing.sm),
            child: Text(
              'Artifact: $artifactId',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),

      ProvenanceNode(:final citation, :final confidence) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.format_quote,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  citation,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ),
              if (confidence != null) ...[
                const SizedBox(width: 8),
                _BadgeWidget(
                  label: '${(confidence * 100).round()}%',
                  variant: confidence >= 0.7
                      ? 'success'
                      : confidence >= 0.4
                          ? 'warning'
                          : 'error',
                ),
              ],
            ],
          ),
        ),

      ImageNode(:final url, :final altText, :final maxHeight) => Semantics(
          label: altText,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight ?? 400),
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Text(
                '[Image unavailable: $altText]',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
    };
  }
}

/// Badge chip helper widget.
class _BadgeWidget extends StatelessWidget {
  final String label;
  final String variant;

  const _BadgeWidget({required this.label, required this.variant});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (bg, fg) = switch (variant) {
      'success' => (Colors.green.shade100, Colors.green.shade800),
      'warning' => (Colors.amber.shade100, Colors.amber.shade900),
      'error' => (colors.errorContainer, colors.onErrorContainer),
      'info' => (colors.secondaryContainer, colors.onSecondaryContainer),
      _ => (colors.surfaceContainerHighest, colors.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// A widget that renders a [UiSurface] using a [UiNodeRenderer] and dispatches
/// actions through an optional [A2UiActionGuard].
class UiSurfaceView extends StatelessWidget {
  final UiSurface surface;
  final UiNodeRenderer renderer;
  final A2UiActionGuard? guard;
  final void Function(UiAction action)? onAction;

  const UiSurfaceView({
    super.key,
    required this.surface,
    this.renderer = const DefaultUiNodeRenderer(),
    this.guard,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return renderer.render(
      context,
      surface.rootNode,
      onAction: onAction != null
          ? (action) {
              final g = guard;
              if (g != null && !g.permits(surface, action)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      g.denyReason(surface, action) ?? 'Action not permitted',
                    ),
                  ),
                );
                return;
              }
              onAction!(action);
            }
          : null,
    );
  }
}
