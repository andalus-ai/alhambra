import 'dart:async';
import 'package:flutter/widgets.dart';
import '../extensions/contribution_ordering.dart';

/// 
class NavigationContribution implements OrderedContribution {
  
  @override
  final String id;

  @override
  final String ownerId;

  final String groupId;
  final String label;
  final IconData? icon;
  final String? viewId;

  @override
  final int order;

  final FutureOr<void> Function(BuildContext context)? action;

  const NavigationContribution({
    required this.id,
    required this.ownerId,
    required this.groupId,
    required this.label,
    this.icon,
    this.viewId,
    this.order = 0,
    this.action,
  });
}
