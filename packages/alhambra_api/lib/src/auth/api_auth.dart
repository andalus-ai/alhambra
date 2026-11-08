/// Authenticated principal identity in the API layer.
final class ApiPrincipal {
  final String userId;
  final String organizationId;
  final Set<String> roles;
  final Set<String> permissions;

  const ApiPrincipal({
    required this.userId,
    required this.organizationId,
    this.roles = const {},
    this.permissions = const {},
  });

  bool hasRole(String role) => roles.contains(role);
  bool hasPermission(String permission) => permissions.contains(permission);
}

/// Boundary interface for evaluating caller authorization before reaching application services.
abstract interface class ApiAuthorizationBoundary {
  /// Returns whether the [principal] is authorized to perform [action] on [resource].
  bool isAuthorized({
    required ApiPrincipal principal,
    required String action,
    required String resource,
    String? resourceId,
  });
}
