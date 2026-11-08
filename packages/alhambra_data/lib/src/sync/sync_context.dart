/// Tenant and authentication context carried into sync operations.
///
/// The sync engine checks this against each [SyncOperation.organizationId]
/// before dispatching — if they don't match, the operation is skipped to
/// prevent cross-tenant mutation after account switching.
final class SyncContext {
  /// The currently active organization — immutable during a sync run.
  final String? organizationId;

  /// Whether the current session is authenticated and valid.
  final bool isAuthenticated;

  const SyncContext({
    this.organizationId,
    this.isAuthenticated = true,
  });

  /// Returns `true` if the given [operationOrgId] is safe to dispatch
  /// under the current context.
  ///
  /// A `null` [operationOrgId] is treated as context-free and always allowed.
  bool canDispatch(String? operationOrgId) {
    if (operationOrgId == null) return true;
    return organizationId == operationOrgId;
  }

  @override
  String toString() =>
      'SyncContext(org: $organizationId, authenticated: $isAuthenticated)';
}
