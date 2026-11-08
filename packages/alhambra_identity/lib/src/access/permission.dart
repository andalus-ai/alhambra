/// An atomic capability in the Alhambra authorization model.
///
/// Permissions follow the `resource:action` convention, e.g.:
/// - `workspace:create`
/// - `analysis:execute`
/// - `knowledge:approve`
///
/// Alhambra does not define which permissions exist — the application
/// configuration declares them. This keeps the core platform agnostic.
final class Permission {
  final String resource;
  final String action;

  const Permission({
    required this.resource,
    required this.action,
  });

  /// Canonical string representation: `resource:action`.
  String get key => '$resource:$action';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Permission &&
          runtimeType == other.runtimeType &&
          resource == other.resource &&
          action == other.action;

  @override
  int get hashCode => Object.hash(resource, action);

  @override
  String toString() => key;
}
