import 'package:flutter/widgets.dart';
import 'route_guard.dart';

/// Defines an endpoint route in the application routing hierarchy.
final class RouteDefinition {
  final String path;
  final Widget Function(BuildContext context, Map<String, String> parameters) builder;
  final List<RouteGuard> guards;
  final String? title;

  const RouteDefinition({
    required this.path,
    required this.builder,
    this.guards = const [],
    this.title,
  });

  @override
  String toString() => 'RouteDefinition($path)';
}
