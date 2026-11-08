import 'package:flutter/material.dart';
import '../theme/alhambra_theme.dart';
import 'app_environment.dart';

/// Top-level configuration for an Alhambra client application.
final class AlhambraAppConfig {
  final String title;
  final RouterConfig<Object>? routerConfig;
  final Widget? home;
  final ThemeData? theme;
  final ThemeData? darkTheme;
  final ThemeMode themeMode;
  final AppEnvironment environment;

  const AlhambraAppConfig({
    required this.title,
    this.routerConfig,
    this.home,
    this.theme,
    this.darkTheme,
    this.themeMode = ThemeMode.system,
    this.environment = AppEnvironment.production,
  }) : assert(
          routerConfig != null || home != null,
          'Either routerConfig or home must be provided to AlhambraAppConfig',
        );

  ThemeData get effectiveTheme => theme ?? AlhambraTheme.light();
  ThemeData get effectiveDarkTheme => darkTheme ?? AlhambraTheme.dark();
}
