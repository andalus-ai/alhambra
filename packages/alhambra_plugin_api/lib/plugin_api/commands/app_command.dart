import 'dart:async';
import 'package:flutter/widgets.dart';
import 'command_context.dart';

/// Represents an application command.
class AppCommand {
  /// The ID of the command.
  final String id;
  /// The title of the command.
  final String title;
  /// The subtitle of the command.
  final String? subtitle;
  /// The category of the command.
  final String category;
  /// The icon for the command.
  final IconData? icon;
  /// The keyboard shortcut for the command.
  final String? shortcut;
  /// The action to perform when the command is executed.
  final FutureOr<void> Function(CommandContext context)? action;

  /// Creates a new [AppCommand] instance.
  const AppCommand({
    required this.id,
    required this.title,
    this.subtitle,
    this.category = 'General',
    this.icon,
    this.shortcut,
    this.action,
  });
}
