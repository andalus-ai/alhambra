import 'package:flutter/material.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

class CoreWorkspaceModes {
  static const String vibe = 'vibe';
  static const String ide = 'ide';
  static const String zen = 'zen';

  static const vibeMode = WorkspaceMode(
    id: vibe,
    title: 'Vibe Coding',
    subtitle: 'Agent-First',
    description: 'AI-first agent-centric flow focused on prompt reasoning, live tool execution, and diff verification.',
    icon: Icons.auto_awesome,
    shortcut: '⌘⌥1',
    category: 'Core',
  );

  static const ideMode = WorkspaceMode(
    id: ide,
    title: 'IDE Workspace',
    subtitle: 'VS Code Style',
    description: 'Full-featured developer workbench with activity bar, primary file tree, multi-split code editors, and terminal.',
    icon: Icons.space_dashboard_outlined,
    shortcut: '⌘⌥2',
    category: 'Core',
  );

  static const zenMode = WorkspaceMode(
    id: zen,
    title: 'Zen Focus',
    subtitle: 'Minimalist',
    description:
        'Distraction-free editor layout with sidebars and panels collapsed.',
    icon: Icons.center_focus_strong,
    shortcut: '⌘⌥3',
    category: 'Core',
  );

  static List<WorkspaceMode> get defaults => const [vibeMode, ideMode, zenMode];
}
