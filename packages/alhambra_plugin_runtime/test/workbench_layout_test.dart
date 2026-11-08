import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

void main() {
  group('Workbench Layout State and Tree Tests', () {
    test('Default layout state is valid and serializes/deserializes to JSON correctly', () {
      final state = WorkbenchLayoutState.defaults();
      expect(state.panes[PaneId.sidebar]?.visible, isTrue);
      expect(state.panes[PaneId.main]?.visible, isTrue);
      expect(state.panes[PaneId.bottom]?.visible, isFalse);
      expect(state.panes[PaneId.secondary]?.visible, isFalse);

      final validator = const WorkbenchLayoutValidator();
      expect(
        () => validator.validate(
          panes: state.panes,
          locations: state.locations,
          groups: state.groups,
          areaLayouts: state.areaLayouts,
        ),
        returnsNormally,
      );

      final json = state.toJson();
      final restored = WorkbenchLayoutState.fromJson(json);
      expect(restored.panes.length, state.panes.length);
      expect(restored.groups.length, state.groups.length);
      expect(restored.areaLayouts.length, state.areaLayouts.length);
      expect(restored.dimensions.sidebarWidth, 280.0);
    });

    test(
      'LayoutTreeEditor splits, updates ratios, and removes groups immutably',
      () {
        const editor = LayoutTreeEditor();
        const navigator = LayoutTreeNavigator();

        const initialRoot = ViewGroupNode(
          id: 'node.main',
          groupId: 'group.main.1',
        );

        // 1. Split root horizontally
        final split1 = editor.splitGroup(
          initialRoot,
          groupId: 'group.main.1',
          newGroupId: 'group.main.2',
          direction: SplitDirection.horizontal,
          placement: SplitPlacement.after,
          ratio: 0.6,
        );

        expect(split1, isA<SplitNode>());
        final splitNode = split1 as SplitNode;
        expect(splitNode.direction, SplitDirection.horizontal);
        expect(splitNode.ratio, 0.6);
        expect((splitNode.first as ViewGroupNode).groupId, 'group.main.1');
        expect((splitNode.second as ViewGroupNode).groupId, 'group.main.2');

        // 2. Navigator inspection
        expect(navigator.collectGroupIds(split1), [
          'group.main.1',
          'group.main.2',
        ]);
        expect(navigator.collectSplitIds(split1), [splitNode.id]);
        expect(navigator.findGroupNode(split1, 'group.main.2'), isNotNull);

        // 3. Update ratio
        final updatedRatio = editor.updateSplitRatio(
          split1,
          splitNodeId: splitNode.id,
          ratio: 0.75,
        );
        expect((updatedRatio as SplitNode).ratio, 0.75);

        // 4. Split nested branch vertically
        final split2 = editor.splitGroup(
          split1,
          groupId: 'group.main.2',
          newGroupId: 'group.main.3',
          direction: SplitDirection.vertical,
          placement: SplitPlacement.before,
        );
        expect(navigator.collectGroupIds(split2), [
          'group.main.1',
          'group.main.3',
          'group.main.2',
        ]);

        // 5. Remove nested group and verify tree collapses
        final afterRemove = editor.removeGroup(split2, groupId: 'group.main.3');
        expect(navigator.collectGroupIds(afterRemove!), [
          'group.main.1',
          'group.main.2',
        ]);
      },
    );

    test('WorkbenchLayoutValidator detects invalid ratios, duplicates, and missing groups', () {
      const validator = WorkbenchLayoutValidator();

      final state = WorkbenchLayoutState.defaults();

      // Corrupted split ratio
      final corruptedRatioState = state.copyWith(
        areaLayouts: {
          ...state.areaLayouts,
          ViewArea.main: SplitNode(
            id: 'invalid.split',
            direction: SplitDirection.horizontal,
            first: const ViewGroupNode(id: 'n1', groupId: CoreViewGroups.main),
            second: const ViewGroupNode(
              id: 'n2',
              groupId: CoreViewGroups.secondary,
            ),
            ratio: 1.5, // Invalid > 1.0
          ),
        },
      );

      expect(
        () => validator.validate(
          panes: corruptedRatioState.panes,
          locations: corruptedRatioState.locations,
          groups: corruptedRatioState.groups,
          areaLayouts: corruptedRatioState.areaLayouts,
        ),
        throwsA(isA<StateError>()),
      );

      // Duplicate group in tree
      final duplicateGroupState = state.copyWith(
        areaLayouts: {
          ...state.areaLayouts,
          ViewArea.main: SplitNode(
            id: 'split.dup',
            direction: SplitDirection.horizontal,
            first: const ViewGroupNode(id: 'n1', groupId: CoreViewGroups.main),
            second: const ViewGroupNode(id: 'n2', groupId: CoreViewGroups.main),
            ratio: 0.5,
          ),
        },
      );

      expect(
        () => validator.validate(
          panes: duplicateGroupState.panes,
          locations: duplicateGroupState.locations,
          groups: duplicateGroupState.groups,
          areaLayouts: duplicateGroupState.areaLayouts,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('WorkbenchController Layout Operations', () {
    late ViewRegistry viewRegistry;
    late WorkbenchController controller;

    setUp(() {
      viewRegistry = ViewRegistry();
      viewRegistry.register(
        const ViewContribution(
          id: 'view.editor.readme',
          ownerId: 'test',
          title: 'README.md',
          preferredPlacement: ViewPlacement.main,
          behavior: ViewBehavior.editor,
          builder: _dummyBuilder,
        ),
      );
      viewRegistry.register(
        const ViewContribution(
          id: 'view.agent.chat',
          ownerId: 'test',
          title: 'Agent Chat',
          preferredPlacement: ViewPlacement.main,
          behavior: ViewBehavior.editor,
          builder: _dummyBuilder,
        ),
      );
      viewRegistry.register(
        const ViewContribution(
          id: 'view.terminal',
          ownerId: 'test',
          title: 'Terminal',
          preferredPlacement: ViewPlacement.bottomPanel,
          behavior: ViewBehavior.panel,
          builder: _dummyBuilder,
        ),
      );
      viewRegistry.register(
        const ViewContribution(
          id: 'view.explorer',
          ownerId: 'test',
          title: 'Explorer',
          preferredPlacement: ViewPlacement.sidebar,
          behavior: ViewBehavior.panel,
          builder: _dummyBuilder,
        ),
      );

      controller = WorkbenchController(views: viewRegistry);
    });

    test('Pane show/hide/resize/toggle operations respect constraints', () {
      expect(controller.layout.pane(PaneId.sidebar).visible, isTrue);

      controller.toggleSidebar(visible: false);
      expect(controller.layout.pane(PaneId.sidebar).visible, isFalse);

      controller.toggleSidebar(visible: true);
      expect(controller.layout.pane(PaneId.sidebar).visible, isTrue);

      // Resize sidebar with constraints
      controller.resizeSidebar(100.0); // Below minSize 180
      expect(controller.layout.pane(PaneId.sidebar).size, 180.0);

      controller.resizeSidebar(500.0);
      expect(controller.layout.pane(PaneId.sidebar).size, 500.0);

      controller.resizeSidebar(1000.0); // Above maxSize 600
      expect(controller.layout.pane(PaneId.sidebar).size, 600.0);
    });

    test('Opening view opens auto-reveals pane and populates tab group', () {
      expect(controller.layout.pane(PaneId.bottom).visible, isFalse);

      // Open terminal in bottom panel
      controller.openView('view.terminal');
      expect(controller.layout.pane(PaneId.bottom).visible, isTrue);
      expect(
        controller.layout.activeViewIn(ViewArea.bottomPanel),
        'view.terminal',
      );
      expect(
        controller.layout.locationOf('view.terminal')?.area,
        ViewArea.bottomPanel,
      );

      // Open multiple views in main group
      controller.openView('view.editor.readme');
      controller.openView('view.agent.chat');

      final mainGroup = controller.layout.group(CoreViewGroups.main);
      expect(mainGroup?.viewIds, ['view.editor.readme', 'view.agent.chat']);
      expect(mainGroup?.activeViewId, 'view.agent.chat');

      // Reorder tabs
      controller.reorderViewInGroup(CoreViewGroups.main, 0, 1);
      expect(controller.layout.group(CoreViewGroups.main)?.viewIds, [
        'view.agent.chat',
        'view.editor.readme',
      ]);
    });

    test('Moving view across groups and splitting views', () {
      controller.openView('view.editor.readme');
      controller.openView('view.agent.chat');

      // Split view.agent.chat to the right
      controller.splitView(
        'view.agent.chat',
        direction: SplitDirection.horizontal,
        placement: SplitPlacement.after,
        ratio: 0.5,
      );

      final mainTree = controller.layout.layoutFor(ViewArea.main);
      expect(mainTree, isA<SplitNode>());

      final splitNode = mainTree as SplitNode;
      expect(splitNode.direction, SplitDirection.horizontal);

      final leftGroup = controller.layout.group(CoreViewGroups.main);
      expect(leftGroup?.viewIds, ['view.editor.readme']);

      final rightGroupId = controller.layout
          .locationOf('view.agent.chat')
          ?.groupId;
      expect(rightGroupId, isNotNull);
      expect(rightGroupId, isNot(CoreViewGroups.main));
      expect(controller.layout.group(rightGroupId!)?.viewIds, [
        'view.agent.chat',
      ]);

      // Split resize session
      controller.beginSplitResize(splitNode.id);
      controller.resizeSplit(splitNode.id, 0.65);
      controller.endSplitResize(splitNode.id);

      final updatedTree =
          controller.layout.layoutFor(ViewArea.main) as SplitNode;
      expect(updatedTree.ratio, 0.65);
    });

    test(
      'Closing last view in bottom panel hides pane when hideWhenEmpty is true',
      () {
        controller.openView('view.terminal');
        expect(controller.layout.pane(PaneId.bottom).visible, isTrue);

        controller.closeView('view.terminal');
        expect(controller.layout.pane(PaneId.bottom).visible, isFalse);
      },
    );

    test('Focus navigation cycles between groups in area', () {
      controller.openView('view.editor.readme');
      controller.openView('view.agent.chat');
      controller.splitView(
        'view.agent.chat',
        direction: SplitDirection.horizontal,
        placement: SplitPlacement.after,
      );

      final rightGroupId = controller.layout
          .locationOf('view.agent.chat')!
          .groupId!;
      expect(controller.layout.activeGroupId(ViewArea.main), rightGroupId);

      controller.focusPreviousGroup(area: ViewArea.main);
      expect(
        controller.layout.activeGroupId(ViewArea.main),
        CoreViewGroups.main,
      );

      controller.focusNextGroup(area: ViewArea.main);
      expect(controller.layout.activeGroupId(ViewArea.main), rightGroupId);
    });
  });

  group('Generic Layout Plugin System & Responsive App Fit Tests', () {
    test('Runtime exposes LayoutPluginRegistry and allows registering custom layouts', () {
      final runtime = ExtensionRuntime();
      expect(runtime.layouts, isNotNull);

      final dummyLayout = _TestAppLayout(
        id: 'org.andalus.layout.custom_ide',
        name: 'Custom IDE Layout',
        suitableKinds: {AppKind.ide, AppKind.codingAgent},
      );

      runtime.layouts.register(dummyLayout);
      expect(runtime.layouts.find('org.andalus.layout.custom_ide'), isNotNull);

      runtime.layouts.activate('org.andalus.layout.custom_ide');
      expect(runtime.layouts.active?.metadata.id, 'org.andalus.layout.custom_ide');
      expect(runtime.layouts.active?.metadata.suitableFor.contains(AppKind.codingAgent), isTrue);
    });

    test('PluginContext activates plugin and registers layouts via UI API', () async {
      final runtime = ExtensionRuntime();
      final manager = PluginManager(runtime: runtime);

      final layoutContributingPlugin = _LayoutContributingPlugin();
      await manager.activate(layoutContributingPlugin);

      expect(runtime.layouts.find('org.andalus.layout.coding_agent'), isNotNull);
      expect(runtime.layouts.find('org.andalus.layout.dashboard'), isNotNull);
      expect(runtime.layouts.find('org.andalus.layout.mobile'), isNotNull);

      runtime.layouts.activate('org.andalus.layout.coding_agent');
      expect(runtime.layouts.active?.metadata.name, 'Aljabr Coding Agent Layout');
    });

    test('LayoutPlugin adapts across small, medium, and large screens and AppKinds', () {
      final codingAgentLayout = _TestAppLayout(
        id: 'test.coding_agent',
        name: 'Coding Agent Layout',
        suitableKinds: {AppKind.codingAgent},
      );

      // Verify slot configuration override
      final slots = LayoutSlotConfig({
        LayoutSlot.mainContent: (ctx) => const Text('Chat Pane'),
        LayoutSlot.secondaryPanel: (ctx) => const Text('Diff Viewer'),
        LayoutSlot.bottomPanel: (ctx) => const Text('Terminal'),
      });

      expect(slots.has(LayoutSlot.mainContent), isTrue);
      expect(slots.has(LayoutSlot.secondaryPanel), isTrue);
      expect(slots.has(LayoutSlot.bottomPanel), isTrue);
      expect(slots.has(LayoutSlot.sidebar), isFalse);

      expect(codingAgentLayout.metadata.suitableFor, contains(AppKind.codingAgent));
    });
  });
}

class _TestAppLayout extends LayoutPlugin {
  final String id;
  final String name;
  final Set<AppKind> suitableKinds;

  _TestAppLayout({
    required this.id,
    required this.name,
    required this.suitableKinds,
  });

  @override
  LayoutPluginMetadata get metadata => LayoutPluginMetadata(
        id: id,
        name: name,
        description: 'Test layout for $name',
        icon: Icons.layers,
        suitableFor: suitableKinds,
      );

  @override
  Widget build(
    BuildContext context, {
    required ScreenClass screenClass,
    required AppKind appKind,
    required LayoutSlotConfig slots,
  }) {
    return const SizedBox();
  }
}

class _LayoutContributingPlugin implements AlhambraPlugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'org.andalus.plugin.layouts_pack',
        name: 'Platform Layouts Pack',
        version: '1.0.0',
      );

  @override
  Future<void> activate(PluginContext context) async {
    context.ui.layouts.register(
      _TestAppLayout(
        id: 'org.andalus.layout.coding_agent',
        name: 'Aljabr Coding Agent Layout',
        suitableKinds: {AppKind.codingAgent},
      ),
    );
    context.ui.layouts.register(
      _TestAppLayout(
        id: 'org.andalus.layout.dashboard',
        name: 'Dashboard Analytics Layout',
        suitableKinds: {AppKind.dashboard},
      ),
    );
    context.ui.layouts.register(
      _TestAppLayout(
        id: 'org.andalus.layout.mobile',
        name: 'Mobile App Layout',
        suitableKinds: {AppKind.mobile},
      ),
    );
  }

  @override
  Future<void> deactivate(PluginContext context) async {}
}

Widget _dummyBuilder(BuildContext context) => const SizedBox();
