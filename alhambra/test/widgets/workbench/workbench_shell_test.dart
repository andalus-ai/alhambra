import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

import 'package:alhambra/providers/module_manager_provider.dart';
import 'package:alhambra/widgets/workbench/workbench_shell.dart';
import 'package:alhambra/widgets/workbench/layout/view_tab.dart';
import 'package:alhambra/widgets/workbench/layout/split_divider.dart';


void main() {
  group('WorkbenchShell and Layout Widget Tests', () {
    late ExtensionRuntime runtime;

    setUp(() {
      runtime = ExtensionRuntime();
      runtime.views.register(
        ViewContribution(
          id: 'view.main.a',
          ownerId: 'test',
          title: 'Main Tab A',
          preferredPlacement: ViewPlacement.main,
          behavior: ViewBehavior.editor,
          builder: (_) => const Text('Content A'),
        ),
      );
      runtime.views.register(
        ViewContribution(
          id: 'view.main.b',
          ownerId: 'test',
          title: 'Main Tab B',
          preferredPlacement: ViewPlacement.main,
          behavior: ViewBehavior.editor,
          builder: (_) => const Text('Content B'),
        ),
      );
      runtime.views.register(
        ViewContribution(
          id: 'view.bottom.term',
          ownerId: 'test',
          title: 'Bottom Terminal',
          preferredPlacement: ViewPlacement.bottomPanel,
          behavior: ViewBehavior.panel,
          builder: (_) => const Text('Terminal Content'),
        ),
      );

    });

    testWidgets('WorkbenchShell renders slots, tabs, and active view content', (tester) async {
      runtime.workbench.openView('view.main.a');
      runtime.workbench.openView('view.main.b');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            extensionRuntimeProvider.overrideWithValue(runtime),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1200,
                height: 800,
                child: WorkbenchShell(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check tabs are rendered in tab strip
      expect(find.text('Main Tab A'), findsOneWidget);
      expect(find.text('Main Tab B'), findsOneWidget);

      // Check active tab content is displayed (Tab B was opened last)
      expect(find.text('Content B'), findsOneWidget);

      // Tap Tab A to switch active tab
      await tester.tap(find.text('Main Tab A'));
      await tester.pumpAndSettle();

      expect(find.text('Content A'), findsOneWidget);
    });

    testWidgets('Splitting view renders SplitDivider and multiple view groups', (tester) async {
      runtime.workbench.openView('view.main.a');
      runtime.workbench.openView('view.main.b');
      runtime.workbench.splitView(
        'view.main.b',
        direction: SplitDirection.horizontal,
        placement: SplitPlacement.after,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            extensionRuntimeProvider.overrideWithValue(runtime),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1200,
                height: 800,
                child: WorkbenchShell(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Both contents should now be visible simultaneously side-by-side!
      expect(find.text('Content A'), findsOneWidget);
      expect(find.text('Content B'), findsOneWidget);

      // SplitDivider is rendered between them
      expect(find.byType(SplitDivider), findsOneWidget);
    });
  });
}
