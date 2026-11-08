import 'package:flutter/material.dart';
import '../navigation/navigation_section.dart';

/// Configuration bundle for initializing an [AppShell].
final class ShellConfig {
  final String title;
  final Widget? logo;
  final List<NavigationSection> navigationSections;
  final List<Widget> actions;
  final Widget? statusWidget;
  final bool enableSearch;

  const ShellConfig({
    required this.title,
    this.logo,
    this.navigationSections = const [],
    this.actions = const [],
    this.statusWidget,
    this.enableSearch = true,
  });
}
