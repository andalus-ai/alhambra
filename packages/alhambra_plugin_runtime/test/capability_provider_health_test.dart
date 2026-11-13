import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

void main() {
  group('CapabilityProviderHealthMonitor', () {
    test('publishes revisioned health and ignores duplicate state', () async {
      final monitor = CapabilityProviderHealthMonitor();
      final events = <CapabilityProviderHealthSnapshot>[];
      final subscription = monitor.changes.listen(events.add);

      final first = monitor.publish(
        ownerId: 'storage',
        state: CapabilityProviderHealthState.degraded,
        reason: 'Latency elevated',
      );
      final duplicate = monitor.publish(
        ownerId: 'storage',
        state: CapabilityProviderHealthState.degraded,
        reason: 'Latency elevated',
      );

      expect(first.revision, 1);
      expect(duplicate.revision, 1);
      expect(first.providers['storage']!.state,
          CapabilityProviderHealthState.degraded);
      await Future<void>.delayed(Duration.zero);
      expect(events.map((event) => event.revision), [1]);

      await subscription.cancel();
      await monitor.close();
    });

    test('publishes recovery with previous state', () async {
      final monitor = CapabilityProviderHealthMonitor();
      monitor.publish(
        ownerId: 'storage',
        state: CapabilityProviderHealthState.unavailable,
      );
      final recovered = monitor.publish(
        ownerId: 'storage',
        state: CapabilityProviderHealthState.healthy,
      );

      expect(recovered.providers['storage']!.previousState,
          CapabilityProviderHealthState.unavailable);
      expect(recovered.revision, 2);
      await monitor.close();
    });

    test('rejects invalid owners and mutations after close', () async {
      final monitor = CapabilityProviderHealthMonitor();
      expect(
        () => monitor.publish(
          ownerId: ' ',
          state: CapabilityProviderHealthState.healthy,
        ),
        throwsArgumentError,
      );
      await monitor.close();
      expect(
        () => monitor.forget('storage'),
        throwsStateError,
      );
    });
  });

  group('CapabilityRevocationPlanner', () {
    test('maps unhealthy dependencies to the configured policy', () async {
      final monitor = CapabilityProviderHealthMonitor();
      final snapshot = monitor.publish(
        ownerId: 'storage',
        state: CapabilityProviderHealthState.unavailable,
        reason: 'Provider process exited',
      );
      const planner = CapabilityRevocationPlanner();

      final decisions = planner.evaluate(
        health: snapshot,
        activePluginIds: const ['plugin-a', 'plugin-b', 'inactive-plugin'],
        providerOwnersByPlugin: const {
          'plugin-a': {'storage'},
          'plugin-b': {'storage'},
          'inactive-plugin': {'storage'},
        },
        policy: CapabilityProviderFailurePolicy.suspend,
      );

      expect(decisions, hasLength(2));
      expect(decisions.map((decision) => decision.pluginId),
          ['plugin-a', 'plugin-b']);
      expect(decisions.every((decision) =>
          decision.action == CapabilityImpactAction.suspend), isTrue);
      expect(decisions.first.reason, 'Provider process exited');
      await monitor.close();
    });

    test('supports notify, degrade, suspend and deactivate policies', () async {
      final monitor = CapabilityProviderHealthMonitor();
      final snapshot = monitor.publish(
        ownerId: 'search',
        state: CapabilityProviderHealthState.degraded,
      );
      const planner = CapabilityRevocationPlanner();
      const expected = {
        CapabilityProviderFailurePolicy.notify: CapabilityImpactAction.notify,
        CapabilityProviderFailurePolicy.degrade:
            CapabilityImpactAction.markDegraded,
        CapabilityProviderFailurePolicy.suspend: CapabilityImpactAction.suspend,
        CapabilityProviderFailurePolicy.deactivate:
            CapabilityImpactAction.deactivate,
      };

      for (final entry in expected.entries) {
        final decisions = planner.evaluate(
          health: snapshot,
          activePluginIds: const ['consumer'],
          providerOwnersByPlugin: const {'consumer': {'search'}},
          policy: entry.key,
        );
        expect(decisions.single.action, entry.value);
      }
      monitor.close();
    });

    test('emits recovery only for an actual unhealthy-to-healthy transition',
        () {
      final monitor = CapabilityProviderHealthMonitor();
      final initial = monitor.publish(
        ownerId: 'storage',
        state: CapabilityProviderHealthState.healthy,
      );
      const planner = CapabilityRevocationPlanner();
      final dependencies = const {'consumer': {'storage'}};

      expect(
        planner.evaluate(
          health: initial,
          activePluginIds: const ['consumer'],
          providerOwnersByPlugin: dependencies,
          policy: CapabilityProviderFailurePolicy.notify,
        ),
        isEmpty,
      );

      monitor.publish(
        ownerId: 'storage',
        state: CapabilityProviderHealthState.unavailable,
      );
      final recovered = monitor.publish(
        ownerId: 'storage',
        state: CapabilityProviderHealthState.healthy,
      );
      final decisions = planner.evaluate(
        health: recovered,
        activePluginIds: const ['consumer'],
        providerOwnersByPlugin: dependencies,
        policy: CapabilityProviderFailurePolicy.deactivate,
      );

      expect(decisions.single.action, CapabilityImpactAction.recovered);
      monitor.close();
    });
  });
}
