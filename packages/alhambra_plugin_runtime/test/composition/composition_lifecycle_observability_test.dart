import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

void main() {
  group('composition lifecycle observability', () {
    test('emits correlated prepare and activate event pairs', () {
      final events = <CompositionLifecycleEvent>[];
      final runtime = DefaultCompositionRuntime(
        onLifecycleEvent: events.add,
      );
      final transaction = runtime.beginTransaction(
        correlationId: 'test-correlation',
        lifecycle: _RecordingLifecycle(),
      )..stage(CommandNode(commandId: 'save', ownerId: 'editor'));

      final result = transaction.commit();

      expect(result, isA<CompositionSuccess>());
      expect(events.map((event) => event.operation), [
        CompositionLifecycleOperation.prepare,
        CompositionLifecycleOperation.prepare,
        CompositionLifecycleOperation.activate,
        CompositionLifecycleOperation.activate,
      ]);
      expect(events.map((event) => event.status), [
        CompositionLifecycleStatus.started,
        CompositionLifecycleStatus.succeeded,
        CompositionLifecycleStatus.started,
        CompositionLifecycleStatus.succeeded,
      ]);
      expect(events.every((event) => event.correlationId == 'test-correlation'), isTrue);
      expect(events.every((event) => event.nodeIds.single == 'command:save'), isTrue);
      expect(events.every((event) => event.ownerIds.single == 'editor'), isTrue);
      expect(events.every((event) => event.timestamp.isUtc), isTrue);
    });

    test('reports activation failure and compensation without publishing nodes', () {
      final events = <CompositionLifecycleEvent>[];
      final runtime = DefaultCompositionRuntime(onLifecycleEvent: events.add);
      final transaction = runtime.beginTransaction(
        correlationId: 'failed-activation',
        lifecycle: _RecordingLifecycle(failActivate: true),
      )..stage(CommandNode(commandId: 'save', ownerId: 'editor'));

      expect(transaction.commit, throwsA(isA<StateError>()));
      expect(runtime.graph.nodes, isEmpty);
      expect(transaction.isRolledBack, isTrue);
      expect(events.map((event) => event.operation), [
        CompositionLifecycleOperation.prepare,
        CompositionLifecycleOperation.prepare,
        CompositionLifecycleOperation.activate,
        CompositionLifecycleOperation.activate,
        CompositionLifecycleOperation.compensate,
        CompositionLifecycleOperation.compensate,
      ]);
      expect(events[3].status, CompositionLifecycleStatus.failed);
      expect(events[3].errorType, 'StateError');
      expect(events[3].errorMessage, contains('activation failed'));
      expect(events.last.status, CompositionLifecycleStatus.succeeded);
    });

    test('a throwing event sink cannot change successful composition', () {
      final runtime = DefaultCompositionRuntime(
        onLifecycleEvent: (_) => throw StateError('diagnostics unavailable'),
      );
      final transaction = runtime.beginTransaction()
        ..stage(CommandNode(commandId: 'save', ownerId: 'editor'));

      expect(transaction.commit(), isA<CompositionSuccess>());
      expect(runtime.graph.nodes.keys, contains('command:save'));
    });
  });
}

class _RecordingLifecycle implements CompositionLifecycle {
  final bool failActivate;

  _RecordingLifecycle({this.failActivate = false});

  @override
  void prepare(List<CompositionNode> orderedNodes) {}

  @override
  void activate(List<CompositionNode> orderedNodes) {
    if (failActivate) throw StateError('activation failed');
  }

  @override
  void deactivate(List<CompositionNode> reverseOrderedNodes) {}

  @override
  void compensate(
    List<CompositionNode> orderedNodes,
    Object error,
    StackTrace stackTrace,
  ) {}
}
