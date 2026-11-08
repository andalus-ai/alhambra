import 'package:flutter/widgets.dart';
import '../extensions/contribution_ordering.dart';

typedef SettingsPageBuilder = Widget Function(BuildContext context);

class SettingsPageContribution implements OrderedContribution {
  @override
  final String id;

  @override
  final String ownerId;

  final String title;
  final String section;
  final IconData? icon;

  @override
  final int order;

  final SettingsPageBuilder builder;

  const SettingsPageContribution({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.section,
    this.icon,
    this.order = 0,
    required this.builder,
  });
}

typedef SettingsContribution = SettingsPageContribution;
