/// Scope at which a setting is defined or resolved.
enum SettingsScope {
  platform,
  organization,
  team,
  user,
  workspace,
}

/// A typed key-value setting bound to a [SettingsScope].
final class Setting {
  final String key;
  final Object? value;
  final SettingsScope scope;

  const Setting({
    required this.key,
    required this.value,
    required this.scope,
  });

  @override
  String toString() => 'Setting($key @ $scope = $value)';
}

/// Context passed to [SettingsResolver.resolve] for cascaded resolution.
final class SettingsContext {
  final String? userId;
  final String? organizationId;
  final String? teamId;
  final String? workspaceId;

  const SettingsContext({
    this.userId,
    this.organizationId,
    this.teamId,
    this.workspaceId,
  });
}

/// Platform settings service — get/set/remove keyed values by scope.
abstract interface class SettingsService {
  Future<Object?> get(
    String key, {
    required SettingsScope scope,
    String? scopeId,
  });

  Future<void> set(
    String key,
    Object? value, {
    required SettingsScope scope,
    String? scopeId,
  });

  Future<void> remove(
    String key, {
    required SettingsScope scope,
    String? scopeId,
  });
}

/// Cascaded settings resolver — walks scope hierarchy from most to least specific.
abstract interface class SettingsResolver {
  Future<Object?> resolve(String key, SettingsContext context);
}

// ---------------------------------------------------------------------------
// In-memory implementation
// ---------------------------------------------------------------------------

/// Composite key: `<scope>:<scopeId?>:<key>`
String _settingKey(String key, SettingsScope scope, String? scopeId) =>
    '${scope.name}:${scopeId ?? ''}:$key';

/// In-memory [SettingsService] for tests.
final class InMemorySettingsService implements SettingsService {
  final Map<String, Object?> _data = {};

  @override
  Future<Object?> get(
    String key, {
    required SettingsScope scope,
    String? scopeId,
  }) async =>
      _data[_settingKey(key, scope, scopeId)];

  @override
  Future<void> set(
    String key,
    Object? value, {
    required SettingsScope scope,
    String? scopeId,
  }) async =>
      _data[_settingKey(key, scope, scopeId)] = value;

  @override
  Future<void> remove(
    String key, {
    required SettingsScope scope,
    String? scopeId,
  }) async =>
      _data.remove(_settingKey(key, scope, scopeId));
}

/// In-memory cascaded [SettingsResolver].
///
/// Resolution order (most → least specific):
/// workspace → user → team → organization → platform
final class CascadedSettingsResolver implements SettingsResolver {
  final SettingsService service;

  const CascadedSettingsResolver(this.service);

  static const _cascade = [
    SettingsScope.workspace,
    SettingsScope.user,
    SettingsScope.team,
    SettingsScope.organization,
    SettingsScope.platform,
  ];

  @override
  Future<Object?> resolve(String key, SettingsContext context) async {
    for (final scope in _cascade) {
      final scopeId = switch (scope) {
        SettingsScope.workspace => context.workspaceId,
        SettingsScope.user => context.userId,
        SettingsScope.team => context.teamId,
        SettingsScope.organization => context.organizationId,
        SettingsScope.platform => null,
      };
      final value = await service.get(key, scope: scope, scopeId: scopeId);
      if (value != null) return value;
    }
    return null;
  }
}
