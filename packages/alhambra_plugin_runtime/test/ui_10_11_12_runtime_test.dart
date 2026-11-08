import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

class _TestResourceEvent implements AlhambraEvent {
  final String path;
  @override
  final EventMetadata metadata;

  _TestResourceEvent(this.path, {EventMetadata? metadata})
      : metadata = metadata ?? EventMetadata(source: 'test');

  @override
  String get type => 'alhambra.resource.changed';
}

class _TestUriMatch implements NavigationMatch {
  final String scheme;
  const _TestUriMatch(this.scheme);

  @override
  bool matches(NavigationIntent intent) {
    if (intent is OpenResourceIntent) {
      return intent.uri.scheme == scheme;
    }
    return false;
  }
}

void main() {
  group('UI-10: Reactive Context & Incremental Resolution', () {
    test('ContextStore notifies changes and supports typed reads', () async {
      final store = InMemoryContextStore();
      final changes = <ContextChange<dynamic>>[];
      final sub = store.changes().listen(changes.add);

      store.set(ContextKeys.workspaceOpen, true);
      store.set(ContextKeys.selectionCount, 3);

      await Future<void>.delayed(Duration.zero);

      expect(store.read(ContextKeys.workspaceOpen), isTrue);
      expect(store.read(ContextKeys.selectionCount), 3);
      expect(changes.length, 2);
      expect(changes.first.key, ContextKeys.workspaceOpen);
      expect(changes.first.current, isTrue);

      await sub.cancel();
      store.dispose();
    });

    test('ContextDependencyIndex and IncrementalContributionResolver evaluate AST conditions incrementally', () {
      final index = ContextDependencyIndex();
      final resolver = IncrementalContributionResolver(index: index);
      final store = InMemoryContextStore();

      // Condition 1: workspaceOpen AND editorActive
      final cond1 = AndCondition([
        const EqualsCondition(ContextKeys.workspaceOpen, true),
        const EqualsCondition(ContextKeys.editorActive, true),
      ]);

      // Condition 2: selectionCount > 0 (ExistsCondition)
      const cond2 = ExistsCondition(ContextKeys.selectionCount);

      index.index('action.save', cond1.dependencies());
      index.index('action.format', cond1.dependencies());
      index.index('action.delete', cond2.dependencies());

      // Set initial context: workspace is open, editor not active
      store.set(ContextKeys.workspaceOpen, true);
      store.set(ContextKeys.editorActive, false);

      // Trigger change: editor becomes active
      final change = ContextChange<bool>(
        key: ContextKeys.editorActive,
        previous: false,
        current: true,
      );
      store.set(ContextKeys.editorActive, true);

      final affectedActive = resolver.resolveAffected(
        change: change,
        conditionByContribution: {
          'action.save': cond1,
          'action.format': cond1,
          'action.delete': cond2,
        },
        context: store,
      );

      // Only action.save and action.format should be re-evaluated and active
      expect(affectedActive, containsAll(['action.save', 'action.format']));
      expect(affectedActive, isNot(contains('action.delete')));
    });
  });

  group('UI-11: Event Bus & Signals Reactivity', () {
    test('Signals update reactively and computed signals recompute automatically', () {
      final signalStore = InMemorySignalStore();
      const countKey = SignalKey<int>('count');
      const doubleKey = SignalKey<int>('double');

      final countSignal = signalStore.getOrCreateMutable<int>(countKey, 5);
      final doubleSignal = signalStore.getOrCreateComputed<int>(
        doubleKey,
        () => countSignal.value * 2,
        [countSignal],
      );

      expect(doubleSignal.value, 10);

      // Mutate count
      countSignal.value = 12;
      expect(doubleSignal.value, 24);

      signalStore.dispose();
    });

    test('ScopedEventBus dispatches typed events by channel with cancellation handle', () async {
      final eventBus = ScopedEventBus();
      const channel = EventChannel<_TestResourceEvent>('alhambra.resource.changed');

      final received = <String>[];
      final subscription = eventBus.subscribe<_TestResourceEvent>(
        channel,
        (event) => received.add(event.path),
      );

      eventBus.emit(_TestResourceEvent('/path/a.dart'));
      eventBus.emit(_TestResourceEvent('/path/b.dart'));

      await Future<void>.delayed(Duration.zero);
      expect(received, ['/path/a.dart', '/path/b.dart']);

      await subscription.cancel();
      eventBus.emit(_TestResourceEvent('/path/c.dart'));
      await Future<void>.delayed(Duration.zero);

      expect(received, ['/path/a.dart', '/path/b.dart']);
      eventBus.dispose();
    });
  });

  group('UI-12: Intent-Based Navigation & Routing', () {
    test('DefaultNavigationService resolves routes and manages history', () async {
      final navService = DefaultNavigationService();

      // Register github URI route
      navService.resolver.registerRoute(
        RouteDefinition(
          id: const RouteId('route.github'),
          view: const ViewId('alhambra.github.pr'),
          match: const _TestUriMatch('github'),
          priority: 10,
        ),
      );

      // 1. Open via Intent
      final result = await navService.open(
        OpenResourceIntent(Uri.parse('github://repo/pr/42')),
      );

      expect(result, isA<NavigationSucceeded>());
      final instanceId = (result as NavigationSucceeded).viewInstanceId;

      expect(navService.history.current?.viewInstanceId, instanceId);

      // 2. Direct OpenViewIntent
      final result2 = await navService.open(
        const OpenViewIntent(ViewId('alhambra.agent.chat')),
      );
      expect(result2, isA<NavigationSucceeded>());
      final chatInstanceId = (result2 as NavigationSucceeded).viewInstanceId;

      expect(navService.history.current?.viewInstanceId, chatInstanceId);
      expect(navService.history.canGoBack, isTrue);

      // 3. Back navigation
      final backEntry = navService.history.back();
      expect(backEntry?.viewInstanceId, instanceId);
      expect(navService.history.canGoForward, isTrue);

      // 4. Forward navigation
      final forwardEntry = navService.history.forward();
      expect(forwardEntry?.viewInstanceId, chatInstanceId);
    });
  });
}
