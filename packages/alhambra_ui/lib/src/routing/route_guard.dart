import 'package:flutter/widgets.dart';

/// Contract for asynchronous navigation / route access checks.
abstract interface class RouteGuard {
  /// Returns `true` if activation can proceed, `false` to block or redirect.
  Future<bool> canActivate(BuildContext context, String path);
}

/// A composite guard that requires all inner guards to pass.
final class CompositeRouteGuard implements RouteGuard {
  final List<RouteGuard> guards;

  const CompositeRouteGuard(this.guards);

  @override
  Future<bool> canActivate(BuildContext context, String path) async {
    for (final guard in guards) {
      final allowed = await guard.canActivate(context, path);
      if (!allowed) return false;
    }
    return true;
  }
}
