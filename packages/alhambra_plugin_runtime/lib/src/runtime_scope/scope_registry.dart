import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'runtime_scope_hierarchy.dart';

final class ScopeRegistry {
  final Map<ScopeId, RuntimeScope> _scopes = {};

  void register(RuntimeScope scope) {
    if (_scopes.containsKey(scope.id)) {
      throw StateError('Scope already registered: ${scope.id}');
    }
    _scopes[scope.id] = scope;
  }

  T? find<T extends RuntimeScope>(ScopeId id) {
    final scope = _scopes[id];
    if (scope is T) {
      return scope;
    }
    return null;
  }

  T require<T extends RuntimeScope>(ScopeId id) {
    final scope = find<T>(id);
    if (scope == null) {
      throw StateError('Scope not found: $id');
    }
    return scope;
  }

  bool contains(ScopeId id) => _scopes.containsKey(id);

  Iterable<RuntimeScope> get values => _scopes.values;

  Future<void> dispose(ScopeId id) async {
    final scope = _scopes.remove(id);
    if (scope == null) return;
    await scope.dispose();
  }

  Future<void> disposeAll() async {
    final scopes = _scopes.values.toList();
    _scopes.clear();
    for (final scope in scopes.reversed) {
      await scope.dispose();
    }
  }
}

final class WorkbenchSessionRegistry {
  final Map<WorkbenchSessionId, WorkbenchSession> _sessions = {};

  void register(WorkbenchSession session) {
    if (_sessions.containsKey(session.sessionId)) {
      throw StateError(
        'Workbench session already registered: ${session.sessionId}',
      );
    }
    _sessions[session.sessionId] = session;
  }

  WorkbenchSession? find(WorkbenchSessionId id) => _sessions[id];

  WorkbenchSession require(WorkbenchSessionId id) {
    final session = find(id);
    if (session == null) {
      throw StateError('Workbench session not found: $id');
    }
    return session;
  }

  bool contains(WorkbenchSessionId id) => _sessions.containsKey(id);

  Iterable<WorkbenchSession> get values => _sessions.values;

  Future<void> dispose(WorkbenchSessionId id) async {
    final session = _sessions.remove(id);
    if (session == null) return;
    await session.dispose();
  }

  Future<void> disposeAll() async {
    final sessions = _sessions.values.toList();
    _sessions.clear();
    for (final session in sessions.reversed) {
      await session.dispose();
    }
  }
}
