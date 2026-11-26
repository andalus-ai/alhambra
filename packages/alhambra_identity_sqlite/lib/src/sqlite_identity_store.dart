import 'dart:convert';

import 'package:alhambra_core/alhambra_core.dart';
import 'package:alhambra_data/alhambra_data.dart';
import 'package:alhambra_identity/alhambra_identity.dart';

/// SQLite-backed membership and role repositories plus authorization audit.
///
/// The caller owns the [Database] lifecycle. Call [initialize] after opening
/// the database and before using any repository method.
final class SqliteIdentityStore
    implements MembershipRepository, RoleRepository, AuthorizationAuditSink {
  final Database _database;

  SqliteIdentityStore(this._database);

  /// Creates the identity tables and indexes if they do not already exist.
  ///
  /// Run this during application startup after opening the database. Schema
  /// evolution beyond this initial version should be managed by host migrations.
  Future<void> initialize() async {
    await _database.execute('''
      CREATE TABLE IF NOT EXISTS alhambra_identity_memberships (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        organization_id TEXT NOT NULL,
        role_ids_json TEXT NOT NULL,
        team_ids_json TEXT NOT NULL,
        active INTEGER NOT NULL CHECK (active IN (0, 1)),
        UNIQUE (user_id, organization_id)
      )
    ''');
    await _database.execute('''
      CREATE INDEX IF NOT EXISTS idx_alhambra_memberships_user
      ON alhambra_identity_memberships (user_id)
    ''');
    await _database.execute('''
      CREATE INDEX IF NOT EXISTS idx_alhambra_memberships_org
      ON alhambra_identity_memberships (organization_id)
    ''');
    await _database.execute('''
      CREATE TABLE IF NOT EXISTS alhambra_identity_roles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        permissions_json TEXT NOT NULL
      )
    ''');
    await _database.execute('''
      CREATE TABLE IF NOT EXISTS alhambra_authorization_audit (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        occurred_at TEXT NOT NULL,
        principal_type TEXT NOT NULL,
        principal_id TEXT NOT NULL,
        permission_key TEXT NOT NULL,
        resource_type TEXT NOT NULL,
        resource_id TEXT NOT NULL,
        organization_id TEXT,
        allowed INTEGER NOT NULL CHECK (allowed IN (0, 1)),
        reason TEXT,
        matched_policies_json TEXT NOT NULL
      )
    ''');
    await _database.execute('''
      CREATE INDEX IF NOT EXISTS idx_alhambra_auth_audit_time
      ON alhambra_authorization_audit (occurred_at)
    ''');
    await _database.execute('''
      CREATE INDEX IF NOT EXISTS idx_alhambra_auth_audit_org
      ON alhambra_authorization_audit (organization_id, occurred_at)
    ''');
  }

  @override
  Future<Membership?> findByUserAndOrg(
    UserId userId,
    OrganizationId organizationId,
  ) async {
    final rows = await _database.query(
      'SELECT * FROM alhambra_identity_memberships '
      'WHERE user_id = :user_id AND organization_id = :organization_id',
      parameters: {
        'user_id': userId.value,
        'organization_id': organizationId.value,
      },
    );
    return rows.isEmpty ? null : _membershipFromRow(rows.first);
  }

  @override
  Future<List<Membership>> findByUser(UserId userId) async {
    final rows = await _database.query(
      'SELECT * FROM alhambra_identity_memberships '
      'WHERE user_id = :user_id ORDER BY organization_id',
      parameters: {'user_id': userId.value},
    );
    return rows.map(_membershipFromRow).toList(growable: false);
  }

  @override
  Future<List<Membership>> findByOrg(OrganizationId organizationId) async {
    final rows = await _database.query(
      'SELECT * FROM alhambra_identity_memberships '
      'WHERE organization_id = :organization_id ORDER BY user_id',
      parameters: {'organization_id': organizationId.value},
    );
    return rows.map(_membershipFromRow).toList(growable: false);
  }

  @override
  Future<void> save(Membership membership) async {
    await _database.execute('''
      INSERT INTO alhambra_identity_memberships
        (id, user_id, organization_id, role_ids_json, team_ids_json, active)
      VALUES
        (:id, :user_id, :organization_id, :role_ids_json, :team_ids_json, :active)
      ON CONFLICT(user_id, organization_id) DO UPDATE SET
        id = excluded.id,
        role_ids_json = excluded.role_ids_json,
        team_ids_json = excluded.team_ids_json,
        active = excluded.active
    ''', parameters: {
      'id': membership.id.value,
      'user_id': membership.userId.value,
      'organization_id': membership.organizationId.value,
      'role_ids_json': jsonEncode(membership.roleIds.toList()..sort()),
      'team_ids_json': jsonEncode(membership.teamIds.toList()..sort()),
      'active': membership.active ? 1 : 0,
    });
  }

  @override
  Future<Role?> findById(RoleId id) async {
    final rows = await _database.query(
      'SELECT * FROM alhambra_identity_roles WHERE id = :id',
      parameters: {'id': id.value},
    );
    return rows.isEmpty ? null : _roleFromRow(rows.first);
  }

  @override
  Future<List<Role>> findByIds(Iterable<RoleId> ids) async {
    final result = <Role>[];
    for (final id in ids) {
      final role = await findById(id);
      if (role != null) result.add(role);
    }
    return result;
  }

  @override
  Future<List<Role>> findAll() async {
    final rows = await _database.query(
      'SELECT * FROM alhambra_identity_roles ORDER BY id',
    );
    return rows.map(_roleFromRow).toList(growable: false);
  }

  @override
  Future<void> save(Role role) async {
    final permissionKeys = role.permissions.map((permission) => permission.key).toList()
      ..sort();
    await _database.execute('''
      INSERT INTO alhambra_identity_roles (id, name, permissions_json)
      VALUES (:id, :name, :permissions_json)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        permissions_json = excluded.permissions_json
    ''', parameters: {
      'id': role.id.value,
      'name': role.name,
      'permissions_json': jsonEncode(permissionKeys),
    });
  }

  /// Appends an authorization decision. This future completes only after the
  /// database adapter reports the insert as complete.
  ///
  /// For strict audit semantics, use a database configured for durable commits
  /// and configure the authorization service with requireAudit: true.
  @override
  Future<void> record(
    AuthorizationRequest request,
    AuthorizationDecision decision,
  ) async {
    final principal = switch (request.principal) {
      UserPrincipal(:final userId) => ('user', userId.value),
      AgentPrincipal(:final agentId) => ('agent', agentId),
      ServicePrincipal(:final serviceId) => ('service', serviceId),
      SystemPrincipal() => ('system', 'system'),
    };

    await _database.execute('''
      INSERT INTO alhambra_authorization_audit (
        occurred_at, principal_type, principal_id, permission_key,
        resource_type, resource_id, organization_id, allowed, reason,
        matched_policies_json
      ) VALUES (
        :occurred_at, :principal_type, :principal_id, :permission_key,
        :resource_type, :resource_id, :organization_id, :allowed, :reason,
        :matched_policies_json
      )
    ''', parameters: {
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
      'principal_type': principal.$1,
      'principal_id': principal.$2,
      'permission_key': request.permission.key,
      'resource_type': request.resource.type,
      'resource_id': request.resource.id.value,
      'organization_id': request.organizationId?.value,
      'allowed': decision.allowed ? 1 : 0,
      'reason': decision.reason,
      'matched_policies_json': jsonEncode(decision.matchedPolicies),
    });
  }

  Membership _membershipFromRow(Map<String, Object?> row) {
    final roleIds = (jsonDecode(_string(row, 'role_ids_json')) as List)
        .map((value) => value as String)
        .toSet();
    final teamIds = (jsonDecode(_string(row, 'team_ids_json')) as List)
        .map((value) => value as String)
        .toSet();
    return Membership(
      id: MembershipId(_string(row, 'id')),
      userId: UserId(_string(row, 'user_id')),
      organizationId: OrganizationId(_string(row, 'organization_id')),
      roleIds: roleIds,
      teamIds: teamIds,
      active: _integer(row, 'active') == 1,
    );
  }

  Role _roleFromRow(Map<String, Object?> row) {
    final keys = (jsonDecode(_string(row, 'permissions_json')) as List)
        .map((value) => value as String);
    return Role(
      id: RoleId(_string(row, 'id')),
      name: _string(row, 'name'),
      permissions: keys.map(_permissionFromKey).toSet(),
    );
  }

  Permission _permissionFromKey(String key) {
    final separator = key.indexOf(':');
    if (separator <= 0 || separator == key.length - 1) {
      throw FormatException('Invalid persisted permission key: $key');
    }
    return Permission(
      resource: key.substring(0, separator),
      action: key.substring(separator + 1),
    );
  }

  String _string(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is! String) throw FormatException('Invalid $key column value');
    return value;
  }

  int _integer(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is int) return value;
    throw FormatException('Invalid $key column value');
  }
}
