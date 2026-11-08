import 'package:flutter/material.dart';
import 'app_config.dart';

/// The root application widget for all Alhambra applications.
/// Wraps MaterialApp or MaterialApp.router with Alhambra themes and environment bindings.
class AlhambraApp extends StatelessWidget {
  final AlhambraAppConfig config;

  const AlhambraApp({
    super.key,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    if (config.routerConfig != null) {
      return MaterialApp.router(
        title: config.title,
        theme: config.effectiveTheme,
        darkTheme: config.effectiveDarkTheme,
        themeMode: config.themeMode,
        routerConfig: config.routerConfig!,
        debugShowCheckedModeBanner: !config.environment.isProduction,
      );
    }

    return MaterialApp(
      title: config.title,
      theme: config.effectiveTheme,
      darkTheme: config.effectiveDarkTheme,
      themeMode: config.themeMode,
      home: config.home,
      debugShowCheckedModeBanner: !config.environment.isProduction,
    );
  }
}
