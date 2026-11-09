import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

void main() {
  group('DefaultCompositionTransaction atomicity', () {
    ServiceNode service(String id, String owner, {Set<CompositionDependency> dependencies = const {}}) =>
        ServiceNode(serviceId: id, ownerId: owner, dependencies: dependencies);

    test('successful commit publishes staged nodes and closes transaction', () {
      final graph = CompositionGraph();
      final transaction = DefaultCompositionTransaction(
        liveGraph: graph,
        onCommit: (_) {},
      );
      transaction.stage(service('new', 'plugin.a'));

      final result = transaction.commit();
      expect(result, isA<CompositionSuccess>());
      expect(graph.nodes.keys, contains('service:new'));
      expect(transaction.isCommitted, isTrue);
      expect(transaction.isRolledBack, isFalse);
      expect(() => transaction.stage(service('late', 'plugin.a')), throwsStateError);
    });

    test('duplicate live node returns owner-aware diagnostic without mutation', () {
      final graph = CompositionGraph()..add(service('shared', 'plugin.live'));
      final transaction = DefaultCompositionTransaction(liveGraph: graph, onCommit: (_) {});
      transaction.stage(service('shared', 'plugin.staged'));

      final result = transaction.commit() as CompositionFailure;
      final diagnostic = result.diagnostics.single as DuplicateNodeDiagnostic;
      expect(diagnostic.existingOwnerId, 'plugin.live');
      expect(diagnostic.newOwnerId, 'plugin.staged');
      expect(graph.nodes['service:shared']!.ownerId, 'plugin.live');
      expect(transaction.isRolledBack, isTrue);
    });

    test('validation failure does not publish staged nodes', () {
      final graph = CompositionGraph();
      final transaction = DefaultCompositionTransaction(liveGraph: graph, onCommit: (_) {});
      transaction.stage(service('consumer', 'plugin.a', dependencies: {
        const CompositionDependency('service:missing'),
      }));

      final result = transaction.commit();
      expect(result, isA<CompositionFailure>());
      expect(graph.nodes, isEmpty);
      expect(transaction.isRolledBack, isTrue);
    });

    test('activation callback failure removes published nodes and closes as rolled back', () {
      final graph = CompositionGraph();
      final transaction = DefaultCompositionTransaction(
        liveGraph: graph,
        onCommit: (_) => throw StateError('activation failed'),
      );
      transaction.stage(service('new', 'plugin.a'));

      expect(transaction.commit, throwsStateError);
      expect(graph.nodes, isEmpty);
      expect(transaction.isCommitted, isFalse);
      expect(transaction.isRolledBack, isTrue);
      expect(() => transaction.commit(), throwsStateError);
    });

    test('stageAll duplicate leaves previously staged set unchanged', () {
      final graph = CompositionGraph();
      final transaction = DefaultCompositionTransaction(liveGraph: graph, onCommit: (_) {});
      transaction.stage(service('first', 'plugin.a'));

      expect(
        () => transaction.stageAll([
          service('second', 'plugin.a'),
          service('first', 'plugin.b'),
        ]),
        throwsArgumentError,
      );
      final result = transaction.commit() as CompositionSuccess;
      expect(result.activatedNodeIds, ['service:first']);
    });
  });
}
