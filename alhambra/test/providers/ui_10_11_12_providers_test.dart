import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra/providers/module_manager_provider.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

void main() {
  group('UI-10 / UI-11 / UI-12 Riverpod Providers Integration', () {
    test('UI-10: Context store updates snapshot notifier reactively', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final store = container.read(contextStoreProvider);
      final initialSnapshot = container.read(contextSnapshotProvider);
      expect(initialSnapshot.get(ContextKeys.editorActive), isNull);

      store.set(ContextKeys.editorActive, true);
      final updatedSnapshot = container.read(contextSnapshotProvider);
      expect(updatedSnapshot.get(ContextKeys.editorActive), true);
    });

    test('UI-11: Signal store resolves mutable and computed signals via Riverpod', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final signalStore = container.read(signalStoreProvider);
      const counterKey = SignalKey<int>('workspace.counter');
      const doubledKey = SignalKey<int>('workspace.counter.doubled');

      final counter = signalStore.getOrCreateMutable<int>(counterKey, 10);
      final doubled = signalStore.getOrCreateComputed<int>(
        doubledKey,
        () => counter.value * 2,
        [counter],
      );

      expect(doubled.value, 20);

      counter.value = 50;
      expect(doubled.value, 100);
    });

    test('UI-12: Navigation service handles intent-based navigation and updates history', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final navService = container.read(navigationServiceProvider);
      final navHistory = container.read(navigationHistoryProvider);

      const testViewId = ViewId('workbench.view.explorer');
      const intent = OpenViewIntent(testViewId);

      final result = await navService.navigate(
        const NavigationRequest(
          intent: intent,
          mode: NavigationOpenMode.reuse,
        ),
      );

      expect(result, isA<NavigationSucceeded>());
      final success = result as NavigationSucceeded;
      expect(success.viewInstanceId.value, startsWith('workbench.view.explorer_'));

      expect(navHistory.current?.intent, equals(intent));
      expect(navHistory.current?.viewInstanceId, equals(success.viewInstanceId));
    });
  });
}
