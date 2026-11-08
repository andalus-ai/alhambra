import '../access/role.dart';

/// Contract for role persistence and resolution.
abstract interface class RoleRepository {
  Future<Role?> findById(RoleId id);
  Future<List<Role>> findByIds(Iterable<RoleId> ids);
  Future<List<Role>> findAll();
  Future<void> save(Role role);
}

/// In-memory implementation of [RoleRepository].
final class InMemoryRoleRepository implements RoleRepository {
  final Map<RoleId, Role> _roles = {};

  @override
  Future<Role?> findById(RoleId id) async => _roles[id];

  @override
  Future<List<Role>> findByIds(Iterable<RoleId> ids) async {
    return ids.map((id) => _roles[id]).whereType<Role>().toList();
  }

  @override
  Future<List<Role>> findAll() async => _roles.values.toList();

  @override
  Future<void> save(Role role) async {
    _roles[role.id] = role;
  }
}
