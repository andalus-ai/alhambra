import 'dart:async';
import 'package:flutter/widgets.dart';
import '../extensions/contribution_ordering.dart';
import 'menu_context.dart';

/// Predicate for determining if a menu item is visible.
typedef MenuVisibilityPredicate = bool Function(MenuContext context);

/// Predicate for determining if a menu item is enabled.
typedef MenuEnabledPredicate = bool Function(MenuContext context);

/// Action to perform when a menu item is invoked.
typedef MenuAction = FutureOr<void> Function(MenuContext context);

/// Represents a contribution to the context menu.
class MenuContribution implements OrderedContribution {
  /// The ID of the contribution.
  @override
  final String id;

  /// The ID of the owner.
  @override
  final String ownerId;

  /// The ID of the target.
  final String targetId;
  /// The label of the menu item.
  final String label;
  /// The icon of the menu item.
  final IconData? icon;

  /// The order of the menu item.
  @override
  final int order;

  /// The group of the menu item.
  final String? group;
  /// The predicate for determining if the menu item is visible.
  final MenuVisibilityPredicate? isVisible;
  /// The predicate for determining if the menu item is enabled.
  final MenuEnabledPredicate? isEnabled;
  /// The action to perform when the menu item is invoked.
  final MenuAction action;

  /// Creates a new [MenuContribution] instance.
  const MenuContribution({
    required this.id,
    required this.ownerId,
    required this.targetId,
    required this.label,
    required this.action,
    this.icon,
    this.order = 0,
    this.group,
    this.isVisible,
    this.isEnabled,
  });
}

/// Alias for [MenuContribution] used for context menu contributions.
typedef ContextMenuContribution = MenuContribution;
