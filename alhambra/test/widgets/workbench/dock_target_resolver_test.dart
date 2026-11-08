import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:alhambra/widgets/workbench/docking/dock_drag_data.dart';
import 'package:alhambra/widgets/workbench/docking/dock_drop_executor.dart';
import 'package:alhambra/widgets/workbench/docking/dock_target.dart';
import 'package:alhambra/widgets/workbench/docking/dock_target_resolver.dart';
import 'package:alhambra/widgets/workbench/docking/drop_intent.dart';


void main() {
  group('DockTargetResolver Unit Tests', () {
    const resolver = DockTargetResolver();
    const dragData = DockDragData(
      viewId: 'view.editor.readme',
      sourceGroupId: 'group.main.1',
    );

    final testTarget = DockTarget(
      groupId: 'group.main.2',
      bounds: const Rect.fromLTWH(0, 40, 1000, 800),
      tabStripBounds: const Rect.fromLTWH(0, 0, 1000, 40),
      tabs: const [
        TabDropTarget(viewId: 't1', bounds: Rect.fromLTWH(0, 0, 100, 40), index: 0),
        TabDropTarget(viewId: 't2', bounds: Rect.fromLTWH(100, 0, 100, 40), index: 1),
      ],
    );

    test('Pointer over tab strip resolves to ReorderDropIntent with correct index', () {
      // Pointer before first tab center (x: 30) -> index 0
      final intent0 = resolver.resolve(
        data: dragData,
        position: const Offset(30, 20),
        targets: [testTarget],
      );
      expect(intent0, isA<ReorderDropIntent>());
      expect((intent0 as ReorderDropIntent).index, 0);

      // Pointer after first tab center (x: 80) -> index 1
      final intent1 = resolver.resolve(
        data: dragData,
        position: const Offset(80, 20),
        targets: [testTarget],
      );
      expect(intent1, isA<ReorderDropIntent>());
      expect((intent1 as ReorderDropIntent).index, 1);

      // Pointer after all tabs (x: 300) -> index 2 (end)
      final intentEnd = resolver.resolve(
        data: dragData,
        position: const Offset(300, 20),
        targets: [testTarget],
      );
      expect(intentEnd, isA<ReorderDropIntent>());
      expect((intentEnd as ReorderDropIntent).index, 2);
    });

    test('Pointer over edges resolves to proportional SplitDropIntent', () {
      // Left 25% edge (x: 100 on 1000px width)
      final leftIntent = resolver.resolve(
        data: dragData,
        position: const Offset(100, 400),
        targets: [testTarget],
      );
      expect(leftIntent, isA<SplitDropIntent>());
      expect((leftIntent as SplitDropIntent).side, DockSide.left);

      // Right 25% edge (x: 900 on 1000px width)
      final rightIntent = resolver.resolve(
        data: dragData,
        position: const Offset(900, 400),
        targets: [testTarget],
      );
      expect(rightIntent, isA<SplitDropIntent>());
      expect((rightIntent as SplitDropIntent).side, DockSide.right);

      // Top 25% edge (y: 100 on y 40..840)
      final topIntent = resolver.resolve(
        data: dragData,
        position: const Offset(500, 100),
        targets: [testTarget],
      );
      expect(topIntent, isA<SplitDropIntent>());
      expect((topIntent as SplitDropIntent).side, DockSide.top);

      // Bottom 25% edge (y: 800 on y 40..840)
      final bottomIntent = resolver.resolve(
        data: dragData,
        position: const Offset(500, 800),
        targets: [testTarget],
      );
      expect(bottomIntent, isA<SplitDropIntent>());
      expect((bottomIntent as SplitDropIntent).side, DockSide.bottom);
    });

    test('Pointer in center resolves to MoveToGroupDropIntent', () {
      final centerIntent = resolver.resolve(
        data: dragData,
        position: const Offset(500, 450),
        targets: [testTarget],
      );
      expect(centerIntent, isA<MoveToGroupDropIntent>());
      expect((centerIntent as MoveToGroupDropIntent).targetGroupId, 'group.main.2');
    });

    test('Pointer outside targets resolves to NoDropIntent', () {
      final outsideIntent = resolver.resolve(
        data: dragData,
        position: const Offset(2000, 2000),
        targets: [testTarget],
      );
      expect(outsideIntent, isA<NoDropIntent>());
    });

    test('Locked enterprise policy suppresses forbidden drop intents', () {
      const lockedResolver = DockTargetResolver(policy: LockedEnterpriseLayoutPolicy());

      final splitIntent = lockedResolver.resolve(
        data: dragData,
        position: const Offset(950, 400),
        targets: [testTarget],
      );
      expect(splitIntent, isA<NoDropIntent>());

      final moveIntent = lockedResolver.resolve(
        data: dragData,
        position: const Offset(500, 450),
        targets: [testTarget],
      );
      expect(moveIntent, isA<NoDropIntent>());
    });

    test('DockDropExecutor invokes controller methods correctly', () {
      final views = ViewRegistry();
      views.register(
        const ViewContribution(
          id: 'v1',
          ownerId: 'test',
          title: 'V1',
          preferredPlacement: ViewPlacement.main,
          builder: _dummy,
        ),
      );
      final controller = WorkbenchController(views: views);
      controller.openView('v1');

      final executor = DockDropExecutor(controller);

      // Execute SplitDropIntent
      executor.execute(
        const DockDragData(viewId: 'v1', sourceGroupId: CoreViewGroups.main),
        const SplitDropIntent(
          targetGroupId: CoreViewGroups.main,
          side: DockSide.right,
        ),
      );

      expect(controller.layout.layoutFor(ViewArea.main), isA<SplitNode>());
    });
  });
}

Widget _dummy(BuildContext context) => const SizedBox();
