import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_extension/alhambra_extension.dart';
import 'package:alhambra/core/commands/command_palette_dialog.dart';

void main() {
  testWidgets('CommandPaletteDialog filters commands based on search query', (tester) async {
    final registry = CommandRegistry();
    registry.register(const AppCommand(id: 'file.save', title: 'File: Save', category: 'File'));
    registry.register(const AppCommand(id: 'agent.ask', title: 'Alhambra: Ask Agent', category: 'Agent'));
    registry.register(const AppCommand(id: 'view.terminal', title: 'View: Toggle Integrated Terminal', category: 'View'));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommandPaletteDialog(registry: registry),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('File: Save'), findsOneWidget);
    expect(find.text('Alhambra: Ask Agent'), findsOneWidget);

    // Enter search query
    await tester.enterText(find.byType(TextField), 'Terminal');
    await tester.pumpAndSettle();

    expect(find.text('View: Toggle Integrated Terminal'), findsOneWidget);
    expect(find.text('File: Save'), findsNothing);
  });
}
