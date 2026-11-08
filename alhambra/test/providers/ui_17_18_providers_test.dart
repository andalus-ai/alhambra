import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_extension/alhambra_extension.dart';
import 'package:alhambra/providers/module_manager_provider.dart';

void main() {
  group('UI-17 & UI-18 Riverpod Providers Test', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('resourceTransactionManagerProvider yields valid transaction manager', () {
      final txManager = container.read(resourceTransactionManagerProvider);
      expect(txManager, isNotNull);
      expect(txManager, isA<ResourceTransactionManager>());
    });

    test('declarativeLayoutControllerProvider and layoutSerializerProvider are wired', () {
      final controller = container.read(declarativeLayoutControllerProvider);
      final serializer = container.read(layoutSerializerProvider);

      expect(controller, isNotNull);
      expect(serializer, isA<LayoutSerializer>());
    });

    test('declarativeLayoutProvider reflects controller state and updates', () {
      final controller = container.read(declarativeLayoutControllerProvider);
      var state = container.read(declarativeLayoutProvider);

      expect(state.openViews, isEmpty);
      expect(state.tree.root, isA<DeclarativePlaceholderNode>());

      final testViewId = ViewInstanceId('view_editor_test');
      controller.openView(testViewId);

      state = container.read(declarativeLayoutProvider);
      expect(state.openViews, contains(testViewId));
      expect(state.tree.root, isA<LayoutViewNode>());
    });
  });
}
