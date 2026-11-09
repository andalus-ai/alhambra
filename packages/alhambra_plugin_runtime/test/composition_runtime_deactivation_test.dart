import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

void main() {
  group('DefaultCompositionRuntime.deactivateOwner', () {
    ServiceNode service(String id, String owner, {Set<CompositionDependency> dependencies = const {}}) {
      return ServiceNode(serviceId: id, ownerId: owner, dependencies: dependencies);
    }

    test('reject leaves graph unchanged when a dependent exists', () {
      final runtime = DefaultCompositionRuntime();
      runtime.graph.add(service('provider', 'owner.a'));
      runtime.graph.add(service('consumer', 'owner.b', dependencies: {
        const CompositionDependency('service:provider'),
      }));

      expect(
        () => runtime.deactivateOwner('owner.a', DeactivationStrategy.reject),
        throwsA(isA<StateError>()),
      );
      expect(runtime.graph.nodes.keys, containsAll(['service:provider', 'service:consumer']));
    });

    test('cascade removes transitive dependents including optional edges', () {
      final runtime = DefaultCompositionRuntime();
      runtime.graph.add(service('provider', 'owner.a'));
      runtime.graph.add(service('consumer', 'owner.b', dependencies: {
        const CompositionDependency('service:provider', required: false),
      }));
      runtime.graph.add(service('downstream', 'owner.c', dependencies: {
        const CompositionDependency('service:consumer'),
      }));

      runtime.deactivateOwner('owner.a', DeactivationStrategy.cascade);
      expect(runtime.graph.nodes, isEmpty);
    });

    test('degrade removes required dependents but retains optional consumers', () {
      final runtime = DefaultCompositionRuntime();
      runtime.graph.add(service('provider', 'owner.a'));
      runtime.graph.add(service('optional', 'owner.b', dependencies: {
        const CompositionDependency('service:provider', required: false),
      }));
      runtime.graph.add(service('required', 'owner.c', dependencies: {
        const CompositionDependency('service:provider'),
      }));
      runtime.graph.add(service('downstream', 'owner.d', dependencies: {
        const CompositionDependency('service:required'),
      }));

      runtime.deactivateOwner('owner.a', DeactivationStrategy.degrade);
      expect(runtime.graph.nodes.keys, contains('service:optional'));
      expect(runtime.graph.nodes.keys, isNot(contains('service:required')));
      expect(runtime.graph.nodes.keys, isNot(contains('service:downstream')));
    });

    test('unknown owner is a no-op and does not notify', () {
      var notifications = 0;
      final runtime = DefaultCompositionRuntime(onOwnerDeactivated: (_) => notifications++);
      runtime.graph.add(service('provider', 'owner.a'));

      runtime.deactivateOwner('missing.owner');
      expect(runtime.graph.nodes.keys, contains('service:provider'));
      expect(notifications, 0);
    });
  });
}
