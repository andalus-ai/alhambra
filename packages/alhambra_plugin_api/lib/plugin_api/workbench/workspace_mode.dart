import 'package:flutter/widgets.dart';
import '../layout/declarative_layout_contracts.dart';

/// Function signature for rendering a custom mode view.
typedef WorkspaceModeViewBuilder = Widget Function(BuildContext context);

/// Descriptor for a top-level workspace layout mode or preset.
class WorkspaceMode {
  /// Unique identifier of the workspace mode (e.g. 'vibe', 'ide', 'zen', 'workflow', 'canvas').
  final String id;

  /// Display title for the mode (e.g. 'Vibe Coding', 'IDE Workspace', 'Workflow Canvas').
  final String title;

  /// Subtitle or short summary describing the focus of this mode.
  final String? subtitle;

  /// Detailed description of what this mode provides.
  final String description;

  /// Icon representing this mode in switchers and menus.
  final IconData icon;

  /// Optional keyboard shortcut label (e.g. 'Ctrl+Alt+1').
  final String? shortcut;

  /// Category or group name.
  final String category;

  /// Whether this mode was contributed as a custom plugin/user mode.
  final bool isCustom;

  /// Optional custom view builder for this workspace mode.
  /// When provided, the workbench host renders this view instead of default shell layout.
  final WorkspaceModeViewBuilder? viewBuilder;

  /// Optional declarative layout preset structure for this mode.
  final DeclarativeLayoutNode? defaultLayout;

  const WorkspaceMode({
    required this.id,
    required this.title,
    this.subtitle,
    required this.description,
    required this.icon,
    this.shortcut,
    this.category = 'Standard',
    this.isCustom = false,
    this.viewBuilder,
    this.defaultLayout,
  });
}
