import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

class _TestPlugin implements AlhambraPlugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'test.plugin',
        name: 'Test Plugin',
        version: '1.0.0',
      );

  @override
  Future<void> activate(PluginContext context) async {
    context.ui.views.register(
      ViewContribution(
        id: 'test.view',
        ownerId: metadata.id,
        title: 'Test View',
        preferredPlacement: ViewPlacement.sidebar,
        builder: (_) => const Text('Active View Content'),
      ),
    );

    context.ui.activityBar.register(
      ActivityBarContribution(
        id: 'test.activity',
        ownerId: metadata.id,
        label: 'Test Activity',
        icon: Icons.star,
        defaultViewId: 'test.view',
      ),
    );

    context.context.register(
      ContextContribution(
        id: 'test.context',
        ownerId: metadata.id,
        contribute: (writer) {
          writer.set(CoreContextKeys.workspaceName, 'Plugin Runtime Workspace');
        },
      ),
    );
  }

  @override
  Future<void> deactivate(PluginContext context) async {}
}

class _TestProPlugin implements AlhambraPlugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'alhambra.pro.analytics',
        name: 'Pro Analytics Plugin',
        version: '1.0.0',
      );

  @override
  Future<void> activate(PluginContext context) async {
    context.ui.views.register(
      ViewContribution(
        id: 'test.pro.analytics',
        ownerId: metadata.id,
        title: 'Pro Analytics',
        preferredPlacement: ViewPlacement.main,
        builder: (_) => const Text('Pro Content'),
      ),
    );
  }

  @override
  Future<void> deactivate(PluginContext context) async {}
}

void main() {
  group('PluginManager and Runtime Tests', () {
    late PluginManager manager;

    setUp(() {
      manager = PluginManager();
    });

    test('PluginManager activates, registers UI contributions and context snapshot, and deactivates cleanly', () async {
      final plugin = _TestPlugin();
      await manager.activate(plugin);

      expect(manager.runtime.views.get('test.view'), isNotNull);
      expect(manager.runtime.activityBar.get('test.activity'), isNotNull);

      // Context test
      final snapshot = manager.runtime.contextService.snapshot();
      expect(snapshot.get(CoreContextKeys.workspaceName), 'Plugin Runtime Workspace');

      // Workbench layout interaction
      manager.runtime.workbench.activateActivity('test.activity', defaultViewId: 'test.view');
      expect(manager.runtime.workbench.activeActivityId, 'test.activity');
      expect(manager.runtime.workbench.layout.activeViewIn(ViewArea.sidebar), 'test.view');

      // Deactivation
      await manager.deactivate('test.plugin');
      expect(manager.runtime.views.get('test.view'), isNull);
      expect(manager.runtime.activityBar.get('test.activity'), isNull);
      expect(manager.runtime.workbench.layout.locationOf('test.view'), isNull);
    });

    testWidgets('WorkbenchViewResolver resolves active, missing, and pro entitlement views correctly', (tester) async {
      final plugin = _TestPlugin();
      final proPlugin = _TestProPlugin();
      await manager.activate(plugin);
      await manager.activate(proPlugin);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final resolverCommunity = WorkbenchViewResolver(
                viewRegistry: manager.runtime.views,
                isProOrHigher: false,
              );

              final resolvedActive = resolverCommunity.resolve('test.view', context);
              expect(resolvedActive, isA<ActivePluginView>());

              final resolvedMissing = resolverCommunity.resolve('non.existent.view', context);
              expect(resolvedMissing, isA<MissingPluginPlaceholderView>());

              final resolvedEntitlement = resolverCommunity.resolve('test.pro.analytics', context);
              expect(resolvedEntitlement, isA<EnterpriseEntitlementPlaceholderView>());

              final resolverPro = WorkbenchViewResolver(
                viewRegistry: manager.runtime.views,
                isProOrHigher: true,
              );
              final resolvedProActive = resolverPro.resolve('test.pro.analytics', context);
              expect(resolvedProActive, isA<ActivePluginView>());

              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('ViewErrorBoundary catches render errors and renders retry card', (tester) async {
      bool shouldThrow = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewErrorBoundary(
              viewId: 'crashing.view',
              viewTitle: 'Crashing Plugin View',
              builder: () {
                if (shouldThrow) {
                  throw Exception('Simulated Plugin View Crash!');
                }
                return const Text('Recovered Plugin View!');
              },
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('View Error: Crashing Plugin View'), findsOneWidget);
      expect(find.textContaining('Simulated Plugin View Crash!'), findsOneWidget);

      // Tap Reload View after fixing error
      shouldThrow = false;
      await tester.tap(find.text('Reload View'));
      await tester.pump();

      expect(find.text('Recovered Plugin View!'), findsOneWidget);
      expect(find.text('View Error: Crashing Plugin View'), findsNothing);
    });
  });
}
