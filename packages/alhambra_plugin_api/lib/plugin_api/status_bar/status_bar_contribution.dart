import 'dart:async';
import 'package:flutter/widgets.dart';
import '../extensions/placed_contribution.dart';
import '../ui/ui_location.dart';
import 'status_bar_alignment.dart';
import 'status_bar_context.dart';

typedef StatusBarTextBuilder = String Function(StatusBarContext context);
typedef StatusBarAction = FutureOr<void> Function(
  BuildContext context,
  StatusBarContext statusContext,
);
typedef StatusBarWidgetBuilder = Widget Function(
  BuildContext context,
  StatusBarContext statusContext,
);

class StatusBarContribution implements PlacedContribution {
  @override
  final String id;

  @override
  final String ownerId;

  final StatusBarAlignment alignment;
  final StatusBarItemKind kind;

  @override
  final int order;

  final String? tooltip;
  final IconData? icon;
  final String? commandId;
  final StatusBarTextBuilder? textBuilder;
  final StatusBarAction? action;
  final StatusBarWidgetBuilder? builder;
  final bool Function(StatusBarContext context)? isVisible;
  final bool Function(StatusBarContext context)? isEnabled;

  @override
  UiLocation get location {
    switch (alignment) {
      case StatusBarAlignment.start:
        return UiLocations.statusBarStart;
      case StatusBarAlignment.center:
        return UiLocations.statusBarCenter;
      case StatusBarAlignment.end:
        return UiLocations.statusBarEnd;
    }
  }

  const StatusBarContribution({
    required this.id,
    required this.ownerId,
    this.alignment = StatusBarAlignment.start,
    this.kind = StatusBarItemKind.text,
    this.order = 0,
    this.tooltip,
    this.icon,
    this.commandId,
    this.textBuilder,
    this.action,
    this.builder,
    this.isVisible,
    this.isEnabled,
  });
}
