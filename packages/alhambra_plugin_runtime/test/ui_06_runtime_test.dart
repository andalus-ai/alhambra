import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

class _TestViewMigration implements ViewIdMigration {
  @override
  String? migrate(String oldViewId) {
    if (oldViewId == 'old.chat.view') return 'alhambra.agent.chat';
    return null;
  }
}

void main() {
  group('UI-06 Phase 19: View Descriptors, Migration & Reconciliation', () {
    test('WorkbenchViewResolver handles missing views with reference store metadata', () {
      final views = ViewRegistry();
      final store = InMemoryViewReferenceStore();
      store.remember(
        const PersistedViewReference(
          viewId: 'github.pr.review',
          title: 'GitHub PR Review',
          pluginId: 'github.plugin',
        ),
      );

      final resolver = WorkbenchViewResolver(
        viewRegistry: views,
        referenceStore: store,
      );

      final resolved = resolver.resolve('github.pr.review');
      expect(resolved, isA<MissingView>());
      expect((resolved as MissingView).title, 'GitHub PR Review');
      expect(resolved.expectedPluginId, 'github.plugin');
    });

    test(
      'WorkbenchLayoutReconciler migrates old view IDs and clamps split ratios',
      () {
        final migration = _TestViewMigration();
        final reconciler = WorkbenchLayoutReconciler(migration: migration);

        final state = WorkbenchLayoutState.empty().copyWith(
          groups: {
            'g1': const ViewGroupState(
              id: 'g1',
              area: ViewArea.main,
              viewIds: ['old.chat.view', 'editor.main'],
              activeViewId: 'old.chat.view',
            ),
          },
          areaLayouts: {
            ViewArea.main: const SplitNode(
              id: 's1',
              direction: SplitDirection.horizontal,
              ratio: 0.99, // out of bounds, should clamp to 0.95
              first: ViewGroupNode(id: 'l1', groupId: 'g1'),
              second: ViewGroupNode(
                id: 'l2',
                groupId: 'g2',
              ), // missing g2 group
            ),
          },
        );

        final result = reconciler.reconcile(state);
        expect(result.repairs.length, greaterThanOrEqualTo(3));
        expect(
          result.state.groups['g1']!.viewIds,
          contains('alhambra.agent.chat'),
        );
        expect(result.state.groups['g1']!.activeViewId, 'alhambra.agent.chat');
        expect(
          result.state.groups.containsKey('g2'),
          isTrue,
        ); // created missing group

        final split = result.state.layoutFor(ViewArea.main) as SplitNode;
        expect(split.ratio, 0.95);
      },
    );
  });

  group('UI-06 Phase 20: Contribution Surfaces & Resolver', () {
    test('UiSurfaceResolver filters by scope, when predicate, and sorts deterministically', () {
      final registry = InMemoryUiContributionRegistry();
      final resolver = DefaultUiSurfaceResolver(registry: registry);

      // Register contributions
      registry.register(
        const UiToolbarContribution(
          id: 'tb.save',
          surfaceId: UiSurfaces.globalToolbar,
          title: 'Save',
          order: ContributionOrder(priority: 10),
        ),
      );

      registry.register(
        UiToolbarContribution(
          id: 'tb.diff',
          surfaceId: UiSurfaces.globalToolbar,
          title: 'Diff',
          order: const ContributionOrder(priority: 20),
          when: (ctx) => ctx.activeViewId == 'alhambra.agent.chat',
        ),
      );

      registry.register(
        const UiToolbarContribution(
          id: 'tb.export',
          surfaceId: UiSurfaces.globalToolbar,
          title: 'Export',
          scope: ViewUiScope(viewId: 'editor.main'),
        ),
      );

      // 1. Resolve for general context
      final res1 = resolver.resolve(
        surfaceId: UiSurfaces.globalToolbar,
        context: const UiContributionContext(activeViewId: 'other.view'),
      );
      expect(res1.map((c) => c.id), ['tb.save']);

      // 2. Resolve when activeViewId is alhambra.agent.chat
      final res2 = resolver.resolve(
        surfaceId: UiSurfaces.globalToolbar,
        context: const UiContributionContext(activeViewId: 'alhambra.agent.chat'),
      );
      expect(res2.map((c) => c.id), ['tb.diff', 'tb.save']);

      // 3. Resolve when activeViewId is editor.main
      final res3 = resolver.resolve(
        surfaceId: UiSurfaces.globalToolbar,
        context: const UiContributionContext(activeViewId: 'editor.main'),
      );
      expect(res3.map((c) => c.id), ['tb.save', 'tb.export']);
    });
  });

  group('UI-06 Phase 21: Shell Composition & Controller', () {
    test('DefaultShellRegionController enforces constraints and manages visibility', () {
      final registry = InMemoryShellRegionRegistry();
      final controller = DefaultShellRegionController(registry: registry);
      final resolver = DefaultShellRegionResolver(
        registry: registry,
        controller: controller,
      );

      // Primary sidebar initial resolution
      var sidebar = resolver.resolve(ShellRegions.primarySidebar);
      expect(sidebar.visible, isTrue);
      expect(sidebar.size, 260.0);

      // Resize primary sidebar within min 180 and max 600
      controller.resize(ShellRegions.primarySidebar, 100); // Below min
      sidebar = resolver.resolve(ShellRegions.primarySidebar);
      expect(sidebar.size, 180.0); // Clamped to min

      controller.resize(ShellRegions.primarySidebar, 750); // Above max
      sidebar = resolver.resolve(ShellRegions.primarySidebar);
      expect(sidebar.size, 600.0); // Clamped to max

      // Hide and show
      controller.hide(ShellRegions.primarySidebar);
      sidebar = resolver.resolve(ShellRegions.primarySidebar);
      expect(sidebar.visible, isFalse);

      controller.show(ShellRegions.primarySidebar);
      sidebar = resolver.resolve(ShellRegions.primarySidebar);
      expect(sidebar.visible, isTrue);
    });
  });

  group('UI-06 Phase 22: UI Composition Runtime & Dependency Graph', () {
    test('CompositionGraph detects missing dependencies and cycles', () {
      final graph = CompositionGraph();

      // Node with missing dependency
      graph.add(
        UiContributionNode(
          contributionId: 'contrib.chat.toolbar',
          surfaceId: UiSurfaces.globalToolbar,
          ownerId: 'plugin.chat',
          dependencies: {const CompositionDependency('command:missing.cmd')},
        ),
      );

      final diagMissing = graph.validate();
      expect(diagMissing, isNotEmpty);
      expect(diagMissing.first, isA<MissingDependencyDiagnostic>());

      // Add circular dependencies
      final cycleGraph = CompositionGraph();
      cycleGraph.add(
        CommandNode(
          commandId: 'cmd.a',
          ownerId: 'p1',
          dependencies: {const CompositionDependency('command:cmd.b')},
        ),
      );
      cycleGraph.add(
        CommandNode(
          commandId: 'cmd.b',
          ownerId: 'p1',
          dependencies: {const CompositionDependency('command:cmd.a')},
        ),
      );

      final diagCycle = cycleGraph.validate();
      expect(diagCycle, isNotEmpty);
      expect(diagCycle.first, isA<CompositionCycleDiagnostic>());
    });

    test(
      'CompositionTransaction commits valid nodes in topological phase order',
      () {
        final runtime = DefaultCompositionRuntime();
        final tx = runtime.beginTransaction();

        tx.stage(
          UiContributionNode(
            contributionId: 'tb.action',
            surfaceId: UiSurfaces.globalToolbar,
            ownerId: 'p1',
            dependencies: {const CompositionDependency('command:cmd.action')},
          ),
        );

        tx.stage(
          CommandNode(
            commandId: 'cmd.action',
            ownerId: 'p1',
            dependencies: {const CompositionDependency('service:srv.data')},
          ),
        );

        tx.stage(ServiceNode(serviceId: 'srv.data', ownerId: 'p1'));

        final result = tx.commit();
        expect(result, isA<CompositionSuccess>());
        expect((result as CompositionSuccess).activatedNodeIds, [
          'service:srv.data',
          'command:cmd.action',
          'contribution:tb.action',
        ]);
      },
    );
  });

  group('UI-06 Phase 23: State Scope & Service Boundaries', () {
    test('ScopedServiceRegistry resolves upward and isolates scopes', () {
      final appScope = ApplicationScope();
      final wsScope = WorkspaceScope(
        id: const WorkspaceId('ws-1'),
        parent: appScope,
      );
      final pluginScope = PluginScope(
        id: const PluginInstanceId('plug-1'),
        parent: wsScope,
      );

      const appKey = ServiceKey<String>('app.title');
      const wsKey = ServiceKey<String>('ws.rootPath');
      const pluginKey = ServiceKey<String>('plugin.secret');

      appScope.services.register(appKey, 'Alhambra IDE');
      wsScope.services.register(wsKey, '/projects/andalus');
      pluginScope.services.register(pluginKey, 'token_xyz');

      // Upward resolution
      expect(pluginScope.services.read(pluginKey), 'token_xyz');
      expect(pluginScope.services.read(wsKey), '/projects/andalus');
      expect(pluginScope.services.read(appKey), 'Alhambra IDE');

      // Downward isolation
      expect(appScope.services.read(pluginKey), isNull);
      expect(appScope.services.read(wsKey), isNull);
      expect(wsScope.services.read(pluginKey), isNull);
    });

    test('Scope hierarchy disposes children first and is idempotent', () async {
      final appScope = ApplicationScope();
      final wsScope = WorkspaceScope(
        id: const WorkspaceId('ws-1'),
        parent: appScope,
      );
      final viewScope = ViewScope(
        id: const ViewInstanceId('view-1'),
        parent: wsScope,
      );

      expect(appScope.state, ScopeState.active);
      expect(wsScope.state, ScopeState.active);
      expect(viewScope.state, ScopeState.active);

      // Dispose workspace scope
      await wsScope.dispose();
      expect(wsScope.state, ScopeState.disposed);
      expect(viewScope.state, ScopeState.disposed);
      expect(appScope.state, ScopeState.active);

      // Idempotent secondary call
      await wsScope.dispose();
      expect(wsScope.state, ScopeState.disposed);
    });
  });
}
