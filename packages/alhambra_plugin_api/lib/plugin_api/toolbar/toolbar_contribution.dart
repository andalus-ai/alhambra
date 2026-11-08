import 'dart:async';
import 'package:flutter/widgets.dart';
import '../extensions/placed_contribution.dart';
import '../ui/ui_location.dart';
import 'toolbar_alignment.dart';
import 'toolbar_context.dart';

typedef ToolbarAction = FutureOr<void> Function(BuildContext context);
typedef ToolbarWidgetBuilder = Widget Function(BuildContext context);

class ToolbarContribution implements PlacedContribution {
  @override
  final String id;

  @override
  final String ownerId;

  final String targetId;
  final ToolbarAlignment alignment;
  final ToolbarItemKind kind;

  @override
  final int order;

  final String? tooltip;
  final IconData? icon;
  final String? commandId;
  final ToolbarAction? action;
  final ToolbarWidgetBuilder? builder;
  final bool Function(ToolbarContext context)? isVisible;
  final bool Function(ToolbarContext context)? isEnabled;

  @override
  UiLocation get location {
    switch (alignment) {
      case ToolbarAlignment.start:
        return UiLocations.toolbarStart;
      case ToolbarAlignment.center:
        return UiLocations.toolbarCenter;
      case ToolbarAlignment.end:
        return UiLocations.toolbarEnd;
    }
  }

  const ToolbarContribution({
    required this.id,
    required this.ownerId,
    this.targetId = ToolbarTargets.app,
    this.alignment = ToolbarAlignment.start,
    this.kind = ToolbarItemKind.action,
    this.order = 0,
    this.tooltip,
    this.icon,
    this.commandId,
    this.action,
    this.builder,
    this.isVisible,
    this.isEnabled,
  });
}
