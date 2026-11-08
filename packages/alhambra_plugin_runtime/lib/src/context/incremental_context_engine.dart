import 'dart:async';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

class InMemoryContextStore implements ContextStore {
  final Map<String, Object?> _values = {};
  final _changeController = StreamController<ContextChange<dynamic>>.broadcast(
    sync: true,
  );
  int _revision = 0;

  @override
  T? read<T>(ContextKey<T> key) {
    final val = _values[key.id];
    if (val is T) return val;
    return null;
  }

  @override
  T readRequired<T>(ContextKey<T> key) {
    final val = read(key);
    if (val == null) {
      throw StateError('Required context key "${key.id}" is not set');
    }
    return val;
  }

  @override
  ContextSnapshot snapshot() {
    return ContextSnapshot(
      revision: _revision,
      values: Map.unmodifiable(_values),
    );
  }

  @override
  void set<T>(ContextKey<T> key, T value) {
    final prev = _values[key.id];
    if (prev == value) return; // No change

    _values[key.id] = value;
    _revision++;
    _changeController.add(
      ContextChange<T>(
        key: key,
        previous: prev is T ? prev : null,
        current: value,
      ),
    );
  }

  @override
  void remove<T>(ContextKey<T> key) {
    if (!_values.containsKey(key.id)) return;
    final prev = _values.remove(key.id);
    _revision++;
    _changeController.add(
      ContextChange<T>(
        key: key,
        previous: prev is T ? prev : null,
        current: null,
      ),
    );
  }

  @override
  Stream<ContextChange<dynamic>> changes() => _changeController.stream;

  void dispose() {
    _changeController.close();
  }
}

class ContextDependencyIndex {
  final Map<String, Set<String>> _dependentsByKey = {};

  void index(String contributionId, Set<ContextKey<dynamic>> keys) {
    for (final key in keys) {
      _dependentsByKey
          .putIfAbsent(key.id, () => <String>{})
          .add(contributionId);
    }
  }

  void unindex(String contributionId) {
    for (final set in _dependentsByKey.values) {
      set.remove(contributionId);
    }
  }

  Set<String> getAffectedContributions(ContextKey<dynamic> key) {
    final set = _dependentsByKey[key.id];
    if (set == null) return const {};
    return Set.unmodifiable(set);
  }

  void clear() {
    _dependentsByKey.clear();
  }
}

class IncrementalContributionResolver {
  final ContextDependencyIndex index;

  const IncrementalContributionResolver({required this.index});

  Set<String> resolveAffected({
    required ContextChange<dynamic> change,
    required Map<String, ContextCondition> conditionByContribution,
    required UiContext context,
  }) {
    final affectedIds = index.getAffectedContributions(change.key);
    final activeIds = <String>{};

    for (final id in affectedIds) {
      final cond = conditionByContribution[id];
      if (cond == null || cond.evaluate(context)) {
        activeIds.add(id);
      }
    }

    return activeIds;
  }
}
