import 'package:flutter/widgets.dart';

/// Represents the context for a command.
class CommandContext {
  /// The build context.
  final BuildContext context;
  /// The ID of the project.
  final String? projectId;
  /// The ID of the session.
  final String? sessionId;

  const CommandContext({
    required this.context,
    this.projectId,
    this.sessionId,
  });
}
