import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_extension/alhambra_extension.dart';
import 'package:alhambra/providers/module_manager_provider.dart';

void main() {
  group('UI-07: Window Scope Shell Layout Isolation', () {
    testWidgets('shell layout state is completely isolated per WindowId', (tester) async {
      const windowA = WindowId('window-a');
      const windowB = WindowId('window-b');

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
                      final stateA = ref.watch(windowShellLayoutProvider(windowA));
                      final stateB = ref.watch(windowShellLayoutProvider(windowB));

                      final visA = stateA.isVisible(ShellRegions.primarySidebar);
                      final visB = stateB.isVisible(ShellRegions.primarySidebar);

                      return Text('$visA-$visB');
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('true-true'), findsOneWidget);

      // Mutate window A only
      container.read(windowShellLayoutProvider(windowA).notifier).toggleRegion(ShellRegions.primarySidebar);
      await tester.pump();

      // Window A is now false, Window B remains true
      expect(find.text('false-true'), findsOneWidget);
    });
  });
}
