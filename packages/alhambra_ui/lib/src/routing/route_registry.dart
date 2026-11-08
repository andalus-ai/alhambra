import 'route_definition.dart';

/// Registry contract for modular application route definitions.
abstract interface class RouteRegistry {
  /// All registered routes.
  List<RouteDefinition> get routes;

  /// Registers a [route].
  void register(RouteDefinition route);

  /// Finds a route matching [path].
  RouteDefinition? find(String path);
}

/// In-memory implementation of [RouteRegistry].
final class DefaultRouteRegistry implements RouteRegistry {
  final Map<String, RouteDefinition> _routes = {};

  DefaultRouteRegistry([List<RouteDefinition>? initialRoutes]) {
    if (initialRoutes != null) {
      for (final r in initialRoutes) {
        _routes[r.path] = r;
      }
    }
  }

  @override
  List<RouteDefinition> get routes => _routes.values.toList();

  @override
  void register(RouteDefinition route) {
    _routes[route.path] = route;
  }

  @override
  RouteDefinition? find(String path) => _routes[path];
}
