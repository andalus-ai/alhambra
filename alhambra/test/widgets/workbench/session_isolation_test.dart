import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_extension/alhambra_extension.dart';
import 'package:alhambra/providers/module_manager_provider.dart';

void main() {
  group('UI-07: Workbench Session State Isolation', () {
    testWidgets('workbench layout state is isolated per WorkbenchSessionId', (tester) async {
      const sessionA = WorkbenchSessionId('session-a');
      const sessionB = WorkbenchSessionId('session-b');

      final container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return Consumer(
                    builder: (context, ref, child) {
                      final stateA = ref.watch(sessionWorkbenchLayoutProvider(sessionA));
                      final stateB = ref.watch(sessionWorkbenchLayoutProvider(sessionB));

                      return Text('${stateA.groups.length}-${stateB.groups.length}');
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Default empty state initializes with 4 standard groups (sidebar, main, bottom, secondary)
      expect(find.text('4-4'), findsOneWidget);

      // Mutate Session A by adding an extra custom view group
      final updatedA = container.read(sessionWorkbenchLayoutProvider(sessionA)).copyWith(
        groups: {
          ...container.read(sessionWorkbenchLayoutProvider(sessionA)).groups,
          'g_custom': const ViewGroupState(
            id: 'g_custom',
            area: ViewArea.main,
            viewIds: ['v1'],
            activeViewId: 'v1',
          ),
        },
      );
      container.read(sessionWorkbenchLayoutProvider(sessionA).notifier).updateState(updatedA);
      await tester.pump();

      // Session A has 5 groups, Session B still has 4
      expect(find.text('5-4'), findsOneWidget);
    });
  });
}
