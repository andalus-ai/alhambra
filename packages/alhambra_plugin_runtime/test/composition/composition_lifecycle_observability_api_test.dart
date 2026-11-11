import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

void main() {
  group('composition lifecycle observability API', () {
    test('delivers events asynchronously and isolates listener failures', () async {
      final runtime = DefaultCompositionRuntime();
      final received = <CompositionLifecycleEvent>[];
      final subscription = runtime.subscribeLifecycleEvents((_) {
        throw StateError('observer failure');
      });
      final second = runtime.subscribeLifecycleEvents(received.add);

      _commit(runtime, 'editor', 'save');
      expect(received, isEmpty, reason: 'delivery must not run in lifecycle callback');

      await Future<void>.delayed(Duration.zero);
      expect(received, hasLength(4));
      expect(runtime.lifecycleEventSubscriberCount, 2);
      expect(runtime.droppedLifecycleEventCount, 0);

      subscription.cancel();
      second.cancel();
      expect(runtime.lifecycleEventSubscriberCount, 0);
      expect(subscription.isCancelled, isTrue);
    });

    test('bounds each subscriber queue and reports dropped events', () async {
      final runtime = DefaultCompositionRuntime();
      final received = <CompositionLifecycleEvent>[];
      final subscription = runtime.subscribeLifecycleEvents(received.add);

      for (var i = 0; i < 40; i++) {
        _commit(runtime, 'editor', 'command-$i');
      }

      expect(runtime.droppedLifecycleEventCount, greaterThan(0));
      expect(subscription.droppedEventCount, runtime.droppedLifecycleEventCount);

      await Future<void>.delayed(Duration.zero);
      expect(received.length, lessThanOrEqualTo(128));
      expect(received.length + subscription.droppedEventCount, 160);
      subscription.cancel();
    });

    test('queries correlation timelines and supports inclusive time windows', () {
      final runtime = DefaultCompositionRuntime();
      _commit(runtime, 'editor', 'save', correlationId: 'install-editor');

      final timeline = runtime.timelineForCorrelation('install-editor');
      expect(timeline, hasLength(4));
      expect(timeline.every((event) => event.correlationId == 'install-editor'), isTrue);

      final firstTimestamp = timeline.first.timestamp;
      expect(
        runtime.queryLifecycleEvents(
          correlationId: 'install-editor',
          from: firstTimestamp,
          to: firstTimestamp,
          limit: 10,
        ),
        hasLength(1),
      );
      expect(
        runtime.queryLifecycleEvents(
          correlationId: 'install-editor',
          before: timeline[1].timestamp,
        ),
        hasLength(1),
      );
      expect(
        () => runtime.queryLifecycleEvents(limit: 0),
        throwsArgumentError,
      );
    });

    test('summarizes owner state and retained lifecycle failures', () {
      final runtime = DefaultCompositionRuntime();
      final transaction = runtime.beginTransaction(
        correlationId: 'failed-install',
        lifecycle: _Lifecycle(failActivate: true),
      )..stage(CommandNode(commandId: 'save', ownerId: 'editor'));

      expect(transaction.commit, throwsA(isA<StateError>()));

      final summary = runtime.ownerLifecycleSummary('editor');
      expect(summary, isNotNull);
      expect(summary!.state, CompositionOwnerState.inactive);
      expect(summary.eventCount, 6);
      expect(summary.failureCount, 1);
      expect(summary.lastFailure!.operation, CompositionLifecycleOperation.activate);
      expect(runtime.ownerLifecycleSummaries.single.ownerId, 'editor');
      expect(runtime.ownerLifecycleSummary('unknown'), isNull);
    });

    test('cancellation prevents queued callbacks and clears pending events', () async {
      final runtime = DefaultCompositionRuntime();
      var calls = 0;
      final subscription = runtime.subscribeLifecycleEvents((_) => calls++);

      _commit(runtime, 'editor', 'save');
      subscription.cancel();
      await Future<void>.delayed(Duration.zero);

      expect(calls, 0);
      expect(subscription.isCancelled, isTrue);
      expect(runtime.lifecycleEventSubscriberCount, 0);
    });
  });
}

void _commit(
  DefaultCompositionRuntime runtime,
  String ownerId,
  String commandId, {
  String? correlationId,
}) {
  final transaction = runtime.beginTransaction(
    correlationId: correlationId ?? commandId,
    lifecycle: _Lifecycle(),
  )..stage(CommandNode(commandId: commandId, ownerId: ownerId));
  expect(transaction.commit(), isA<CompositionSuccess>());
}

class _Lifecycle implements CompositionLifecycle {
  final bool failActivate;

  _Lifecycle({this.failActivate = false});

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
