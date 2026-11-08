import 'package:flutter/widgets.dart';

import '../views/view_area.dart';

enum ContributionOwnerKind { core, plugin, pro, enterprise }

class ContributionOwner {
  final String id;
  final ContributionOwnerKind kind;

  const ContributionOwner({
    required this.id,
    this.kind = ContributionOwnerKind.plugin,
  });

  static const core = ContributionOwner(
    id: 'alhambra.core',
    kind: ContributionOwnerKind.core,
  );
}

class ContributionOrder {
  final String? before;
  final String? after;
  final int priority;

  const ContributionOrder({this.before, this.after, this.priority = 0});

  const ContributionOrder.defaultOrder()
    : before = null,
      after = null,
      priority = 0;
}

class ContributionGroup {
  final String id;
  final ContributionOrder order;

  const ContributionGroup({
    required this.id,
    this.order = const ContributionOrder.defaultOrder(),
  });
}

sealed class UiContributionScope {
  const UiContributionScope();
}

final class GlobalUiScope extends UiContributionScope {
  const GlobalUiScope();
}

final class ViewUiScope extends UiContributionScope {
  final String? viewId;
  const ViewUiScope({this.viewId});
}

final class AreaUiScope extends UiContributionScope {
  final ViewArea area;
  const AreaUiScope(this.area);
}

final class ContextUiScope extends UiContributionScope {
  final String contextKey;
  const ContextUiScope(this.contextKey);
}

class UiContributionContext {
  final String? activeViewId;
  final String? activeGroupId;
  final ViewArea? activeArea;
  final String? workspaceId;
  final Map<String, Object?> values;

  const UiContributionContext({
    this.activeViewId,
    this.activeGroupId,
    this.activeArea,
    this.workspaceId,
    this.values = const {},
  });
}

typedef UiContributionPredicate = bool Function(UiContributionContext context);

abstract class UiContribution {
  String get id;
  String get surfaceId;
  ContributionOwner get owner;
  ContributionOrder get order;
  UiContributionScope get scope;
  UiContributionPredicate? get when;
  Set<String> get dependencies;
}

abstract interface class ContributionRegistration {
  void dispose();
}

class UiToolbarContribution implements UiContribution {
  @override
  final String id;

  @override
  final String surfaceId;

  @override
  final ContributionOwner owner;

  @override
  final ContributionOrder order;

  @override
  final UiContributionScope scope;

  @override
  final UiContributionPredicate? when;

  @override
  final Set<String> dependencies;

  final String? commandId;
  final String? title;
  final IconData? icon;
  final String? group;

  const UiToolbarContribution({
    required this.id,
    required this.surfaceId,
    this.commandId,
    this.title,
    this.icon,
    this.group,
    this.owner = ContributionOwner.core,
    this.order = const ContributionOrder.defaultOrder(),
    this.scope = const GlobalUiScope(),
    this.when,
    this.dependencies = const {},
  });
}

class UiStatusItemContribution implements UiContribution {
  @override
  final String id;

  @override
  final String surfaceId;

  @override
  final ContributionOwner owner;

  @override
  final ContributionOrder order;

  @override
  final UiContributionScope scope;

  @override
  final UiContributionPredicate? when;

  @override
  final Set<String> dependencies;

  final String? commandId;
  final String? text;
  final IconData? icon;
  final String? tooltip;

  const UiStatusItemContribution({
    required this.id,
    required this.surfaceId,
    this.commandId,
    this.text,
    this.icon,
    this.tooltip,
    this.owner = ContributionOwner.core,
    this.order = const ContributionOrder.defaultOrder(),
    this.scope = const GlobalUiScope(),
    this.when,
    this.dependencies = const {},
  });
}

class UiMenuContribution implements UiContribution {
  @override
  final String id;

  @override
  final String surfaceId;

  @override
  final ContributionOwner owner;

  @override
  final ContributionOrder order;

  @override
  final UiContributionScope scope;

  @override
  final UiContributionPredicate? when;

  @override
  final Set<String> dependencies;

  final String? commandId;
  final String title;
  final IconData? icon;
  final String? group;

  const UiMenuContribution({
    required this.id,
    required this.surfaceId,
    required this.title,
    this.commandId,
    this.icon,
    this.group,
    this.owner = ContributionOwner.core,
    this.order = const ContributionOrder.defaultOrder(),
    this.scope = const GlobalUiScope(),
    this.when,
    this.dependencies = const {},
  });
}

class UiActivityBarContribution implements UiContribution {
  @override
  final String id;

  @override
  final String surfaceId;

  @override
  final ContributionOwner owner;

  @override
  final ContributionOrder order;

  @override
  final UiContributionScope scope;

  @override
  final UiContributionPredicate? when;

  @override
  final Set<String> dependencies;

  final String targetViewId;
  final String title;
  final IconData icon;
  final IconData? activeIcon;
  final int priority;

  const UiActivityBarContribution({
    required this.id,
    this.surfaceId = 'alhambra.ui.activityBar',
    required this.targetViewId,
    required this.title,
    required this.icon,
    this.activeIcon,
    this.priority = 0,
    this.owner = ContributionOwner.core,
    this.order = const ContributionOrder.defaultOrder(),
    this.scope = const GlobalUiScope(),
    this.when,
    this.dependencies = const {},
  });
}

class UiEmptyStateContribution implements UiContribution {
  @override
  final String id;

  @override
  final String surfaceId;

  @override
  final ContributionOwner owner;

  @override
  final ContributionOrder order;

  @override
  final UiContributionScope scope;

  @override
  final UiContributionPredicate? when;

  @override
  final Set<String> dependencies;

  final String title;
  final String description;
  final String? actionCommandId;
  final String? actionLabel;

  const UiEmptyStateContribution({
    required this.id,
    required this.surfaceId,
    required this.title,
    required this.description,
    this.actionCommandId,
    this.actionLabel,
    this.owner = ContributionOwner.core,
    this.order = const ContributionOrder.defaultOrder(),
    this.scope = const GlobalUiScope(),
    this.when,
    this.dependencies = const {},
  });
}

class UiCustomWidgetContribution implements UiContribution {
  @override
  final String id;

  @override
  final String surfaceId;

  @override
  final ContributionOwner owner;

  @override
  final ContributionOrder order;

  @override
  final UiContributionScope scope;

  @override
  final UiContributionPredicate? when;

  @override
  final Set<String> dependencies;

  final Widget Function(
    BuildContext context,
    UiContributionContext contributionContext,
  )
  builder;

  const UiCustomWidgetContribution({
    required this.id,
    required this.surfaceId,
    required this.builder,
    this.owner = ContributionOwner.core,
    this.order = const ContributionOrder.defaultOrder(),
    this.scope = const GlobalUiScope(),
    this.when,
    this.dependencies = const {},
  });
}
