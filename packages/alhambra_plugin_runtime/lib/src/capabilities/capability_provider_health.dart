import 'dart:async';

/// Operational health of a capability provider. This is not authorization.
enum CapabilityProviderHealthState {
  healthy,
  degraded,
  unavailable,
}

/// Immutable health record for one provider owner.
final class CapabilityProviderHealth {
  final String ownerId;
  final CapabilityProviderHealthState state;
  final int revision;
  final String? reason;
  final DateTime observedAt;

  const CapabilityProviderHealth({
    required this.ownerId,
    required this.state,
    required this.revision,
    required this.observedAt,
    this.reason,
  });
}

/// Revisioned health projection for all known providers.
final class CapabilityProviderHealthSnapshot {
  final int revision;
  final Map<String, CapabilityProviderHealth> providers;

  CapabilityProviderHealthSnapshot({
    required this.revision,
    required Map<String, CapabilityProviderHealth> providers,
  }) : providers = Map<String, CapabilityProviderHealth>.unmodifiable(
          providers,
        );
}

/// Host-driven provider health publication.
///
/// This service does not probe providers itself. Adapters may publish results
/// from local lifecycle hooks, health checks, or remote monitoring systems.
class CapabilityProviderHealthMonitor {
  final Map<String, CapabilityProviderHealth> _providers = {};
  final StreamController<CapabilityProviderHealthSnapshot> _changes =
      StreamController<CapabilityProviderHealthSnapshot>.broadcast();

  int _revision = 0;
  bool _closed = false;

  int get revision => _revision;
  Stream<CapabilityProviderHealthSnapshot> get changes => _changes.stream;

  CapabilityProviderHealthSnapshot snapshot() =>
      CapabilityProviderHealthSnapshot(
        revision: _revision,
        providers: _providers,
      );

  /// Publishes a provider state. Repeated identical states are no-ops.
  CapabilityProviderHealthSnapshot publish({
    required String ownerId,
    required CapabilityProviderHealthState state,
    String? reason,
    DateTime? observedAt,
  }) {
    _ensureOpen();
    final owner = ownerId.trim();
    if (owner.isEmpty) {
      throw ArgumentError.value(ownerId, 'ownerId', 'Must not be empty');
    }
    final normalizedReason = reason?.trim();
    if (_providers[owner]?.state == state &&
        _providers[owner]?.reason == normalizedReason) {
      return snapshot();
    }

    _revision++;
    _providers[owner] = CapabilityProviderHealth(
      ownerId: owner,
      state: state,
      revision: _revision,
      reason: normalizedReason?.isEmpty == true ? null : normalizedReason,
      observedAt: observedAt ?? DateTime.now().toUtc(),
    );
    final current = snapshot();
    _changes.add(current);
    return current;
  }

  /// Removes health tracking for an owner, publishing the new projection.
  bool forget(String ownerId) {
    _ensureOpen();
    final owner = ownerId.trim();
    if (owner.isEmpty) {
      throw ArgumentError.value(ownerId, 'ownerId', 'Must not be empty');
    }
    if (_providers.remove(owner) == null) return false;
    _revision++;
    _changes.add(snapshot());
    return true;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _changes.close();
  }

  void _ensureOpen() {
    if (_closed) throw StateError('CapabilityProviderHealthMonitor is closed.');
  }
}

/// Host-selected response when a dependency provider is degraded or lost.
enum CapabilityProviderFailurePolicy {
  notify,
  degrade,
  suspend,
  deactivate,
}

/// Recommended response for an active plugin affected by a provider transition.
enum CapabilityImpactAction {
  notify,
  markDegraded,
  suspend,
  deactivate,
  recovered,
}

final class CapabilityImpactDecision {
  final String pluginId;
  final String providerOwnerId;
  final CapabilityProviderHealthState providerState;
  final CapabilityImpactAction action;
  final String? reason;

  const CapabilityImpactDecision({
    required this.pluginId,
    required this.providerOwnerId,
    required this.providerState,
    required this.action,
    this.reason,
  });
}

/// Pure impact planner. The host supplies the dependency graph because only
/// the host knows which active plugins actually consume each provider.
class CapabilityRevocationPlanner {
  const CapabilityRevocationPlanner();

  List<CapabilityImpactDecision> evaluate({
    required CapabilityProviderHealthSnapshot health,
    required Iterable<String> activePluginIds,
    required Map<String, Set<String>> providerOwnersByPlugin,
    required CapabilityProviderFailurePolicy policy,
  }) {
    final active = activePluginIds.toSet();
    final decisions = <CapabilityImpactDecision>[];

    final pluginIds = active.toList()..sort();
    for (final pluginId in pluginIds) {
      final owners = providerOwnersByPlugin[pluginId]?.toList() ?? <String>[];
      owners.sort();
      for (final owner in owners) {
        final provider = health.providers[owner];
        if (provider == null || provider.state == CapabilityProviderHealthState.healthy) {
          continue;
        }
        decisions.add(CapabilityImpactDecision(
          pluginId: pluginId,
          providerOwnerId: owner,
          providerState: provider.state,
          action: _actionFor(provider.state, policy),
          reason: provider.reason,
        ));
      }
    }
    return List<CapabilityImpactDecision>.unmodifiable(decisions);
  }

  CapabilityImpactAction _actionFor(
    CapabilityProviderHealthState state,
    CapabilityProviderFailurePolicy policy,
  ) {
    if (state == CapabilityProviderHealthState.healthy) {
      return CapabilityImpactAction.recovered;
    }
    return switch (policy) {
      CapabilityProviderFailurePolicy.notify => CapabilityImpactAction.notify,
      CapabilityProviderFailurePolicy.degrade => CapabilityImpactAction.markDegraded,
      CapabilityProviderFailurePolicy.suspend => CapabilityImpactAction.suspend,
      CapabilityProviderFailurePolicy.deactivate => CapabilityImpactAction.deactivate,
    };
  }
}
