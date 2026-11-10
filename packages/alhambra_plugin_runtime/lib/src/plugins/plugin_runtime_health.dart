/// Product-neutral lifecycle and health projection for plugin runtimes.
///
/// This registry observes lifecycle transitions; it does not activate/deactivate
/// plugins or replace PluginManager. Hosts and coordinators report transitions.
enum PluginRuntimeState {
  discovered,
  validated,
  starting,
  active,
  degraded,
  stopping,
  stopped,
  failed,
}

class PluginRuntimeTransition {
  final String pluginId;
  final PluginRuntimeState previous;
  final PluginRuntimeState current;
  final DateTime occurredAt;
  final String? reason;

  const PluginRuntimeTransition({
    required this.pluginId,
    required this.previous,
    required this.current,
    required this.occurredAt,
    this.reason,
  });
}

class PluginRuntimeHealthSnapshot {
  final String pluginId;
  final PluginRuntimeState state;
  final DateTime updatedAt;
  final String? reason;
  final int transitionCount;

  const PluginRuntimeHealthSnapshot({
    required this.pluginId,
    required this.state,
    required this.updatedAt,
    this.reason,
    required this.transitionCount,
  });
}

/// Validates and records lifecycle state reported by the host.
///
/// The registry is deliberately synchronous and in-memory. Persistence,
/// event delivery, health probes, and restart policy belong to host adapters.
class PluginRuntimeHealthRegistry {
  final Map<String, PluginRuntimeHealthSnapshot> _snapshots = {};
  final List<PluginRuntimeTransition> _history = [];

  Map<String, PluginRuntimeHealthSnapshot> get snapshots =>
      Map.unmodifiable(_snapshots);

  List<PluginRuntimeTransition> get history =>
      List.unmodifiable(_history);

  PluginRuntimeHealthSnapshot? snapshotOf(String pluginId) =>
      _snapshots[pluginId.trim()];

  PluginRuntimeTransition transition({
    required String pluginId,
    required PluginRuntimeState next,
    DateTime? at,
    String? reason,
  }) {
    final id = pluginId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(pluginId, 'pluginId', 'must not be empty');
    }

    final timestamp = at ?? DateTime.now().toUtc();
    final previousSnapshot = _snapshots[id];
    final previous = previousSnapshot?.state ?? PluginRuntimeState.discovered;

    if (!_allowed(previous, next)) {
      throw PluginRuntimeTransitionException(
        pluginId: id,
        from: previous,
        to: next,
      );
    }

    final event = PluginRuntimeTransition(
      pluginId: id,
      previous: previous,
      current: next,
      occurredAt: timestamp,
      reason: reason,
    );
    _history.add(event);
    _snapshots[id] = PluginRuntimeHealthSnapshot(
      pluginId: id,
      state: next,
      updatedAt: timestamp,
      reason: reason,
      transitionCount: (previousSnapshot?.transitionCount ?? 0) + 1,
    );
    return event;
  }

  /// Remove projection state only; this does not perform plugin cleanup.
  void forget(String pluginId) {
    final id = pluginId.trim();
    if (id.isEmpty) return;
    _snapshots.remove(id);
  }

  bool _allowed(PluginRuntimeState from, PluginRuntimeState to) {
    if (from == to) return true;
    return switch (from) {
      PluginRuntimeState.discovered =>
        to == PluginRuntimeState.validated ||
            to == PluginRuntimeState.failed ||
            to == PluginRuntimeState.stopped,
      PluginRuntimeState.validated =>
        to == PluginRuntimeState.starting ||
            to == PluginRuntimeState.failed ||
            to == PluginRuntimeState.stopped,
      PluginRuntimeState.starting =>
        to == PluginRuntimeState.active ||
            to == PluginRuntimeState.degraded ||
            to == PluginRuntimeState.failed ||
            to == PluginRuntimeState.stopping,
      PluginRuntimeState.active =>
        to == PluginRuntimeState.degraded ||
            to == PluginRuntimeState.stopping ||
            to == PluginRuntimeState.failed,
      PluginRuntimeState.degraded =>
        to == PluginRuntimeState.active ||
            to == PluginRuntimeState.stopping ||
            to == PluginRuntimeState.failed,
      PluginRuntimeState.stopping =>
        to == PluginRuntimeState.stopped ||
            to == PluginRuntimeState.failed,
      PluginRuntimeState.stopped =>
        to == PluginRuntimeState.discovered,
      PluginRuntimeState.failed =>
        to == PluginRuntimeState.discovered ||
            to == PluginRuntimeState.starting ||
            to == PluginRuntimeState.stopping,
    };
  }
}

class PluginRuntimeTransitionException implements Exception {
  final String pluginId;
  final PluginRuntimeState from;
  final PluginRuntimeState to;

  const PluginRuntimeTransitionException({
    required this.pluginId,
    required this.from,
    required this.to,
  });

  @override
  String toString() =>
      'Invalid plugin lifecycle transition for "$pluginId": $from -> $to';
}
