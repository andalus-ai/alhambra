import 'package:flutter/widgets.dart';
import 'authorized.dart';

/// A presentation gate that renders [child] if the current context has [permission],
/// otherwise renders [fallback] (or an empty widget).
///
/// NOTE: UI authorization is for interaction control and UX cleanliness.
/// Backend/application service authorization remains authoritative.
class PermissionGate extends StatelessWidget {
  final String permission;
  final Widget child;
  final Widget? fallback;
  final UiAuthorizationResolver? resolver;

  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
    this.resolver,
  });

  @override
  Widget build(BuildContext context) {
    final activeResolver = resolver ?? AuthorizationScope.maybeOf(context);
    final allowed = activeResolver?.hasPermission(permission) ?? false;

    if (allowed) {
      return child;
    }

    return fallback ?? const SizedBox.shrink();
  }
}
