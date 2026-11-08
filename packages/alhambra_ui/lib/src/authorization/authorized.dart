import 'package:flutter/widgets.dart';

/// Contract for checking authorization decisions within UI components.
abstract interface class UiAuthorizationResolver {
  /// Evaluates whether the current user has the given [permissionKey].
  bool hasPermission(String permissionKey);

  /// Evaluates whether the current user has the given [roleId].
  bool hasRole(String roleId);
}

/// A simple [UiAuthorizationResolver] configured with explicit permission and role sets.
final class SimpleUiAuthorizationResolver implements UiAuthorizationResolver {
  final Set<String> permissions;
  final Set<String> roles;

  const SimpleUiAuthorizationResolver({
    this.permissions = const {},
    this.roles = const {},
  });

  @override
  bool hasPermission(String permissionKey) => permissions.contains(permissionKey);

  @override
  bool hasRole(String roleId) => roles.contains(roleId);
}

/// InheritedWidget providing [UiAuthorizationResolver] to descendant widgets.
class AuthorizationScope extends InheritedWidget {
  final UiAuthorizationResolver resolver;

  const AuthorizationScope({
    super.key,
    required this.resolver,
    required super.child,
  });

  static UiAuthorizationResolver? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AuthorizationScope>()?.resolver;
  }

  static UiAuthorizationResolver of(BuildContext context) {
    final resolver = maybeOf(context);
    assert(resolver != null, 'No AuthorizationScope found in context');
    return resolver!;
  }

  @override
  bool updateShouldNotify(AuthorizationScope oldWidget) => resolver != oldWidget.resolver;
}
