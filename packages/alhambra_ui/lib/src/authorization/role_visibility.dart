import 'package:flutter/widgets.dart';
import 'authorized.dart';

/// A presentation gate that renders [child] if the current context possesses [roleId],
/// otherwise renders [fallback] (or an empty widget).
class RoleVisibility extends StatelessWidget {
  final String roleId;
  final Widget child;
  final Widget? fallback;
  final UiAuthorizationResolver? resolver;

  const RoleVisibility({
    super.key,
    required this.roleId,
    required this.child,
    this.fallback,
    this.resolver,
  });

  @override
  Widget build(BuildContext context) {
    final activeResolver = resolver ?? AuthorizationScope.maybeOf(context);
    final allowed = activeResolver?.hasRole(roleId) ?? false;

    if (allowed) {
      return child;
    }

    return fallback ?? const SizedBox.shrink();
  }
}
