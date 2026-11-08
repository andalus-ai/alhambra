import '../access/permission.dart';

/// Contract for cataloging registered platform permissions.
abstract interface class PermissionRepository {
  Future<Permission?> findByKey(String key);
  Future<List<Permission>> findAll();
  Future<void> save(Permission permission);
}

/// In-memory implementation of [PermissionRepository].
final class InMemoryPermissionRepository implements PermissionRepository {
  final Map<String, Permission> _permissions = {};

  @override
  Future<Permission?> findByKey(String key) async => _permissions[key];

  @override
  Future<List<Permission>> findAll() async => _permissions.values.toList();

  @override
  Future<void> save(Permission permission) async {
    _permissions[permission.key] = permission;
  }
}
