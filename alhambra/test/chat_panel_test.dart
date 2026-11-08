import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_coding_core/alhambra_coding_core.dart';
import 'package:alhambra_plugin_chat/alhambra_plugin_chat.dart';

void main() {
  testWidgets('ChatPanel renders messages', (WidgetTester tester) async {
    final container = ProviderContainer();
    container.read(activeSessionIdProvider.notifier).state = 'test-session';

    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: ChatPanel(slashCommands: []),
            ),
          ),
        ),
      ),
    );

    final notifier =
        container.read(chatTranscriptProvider('test-session').notifier);

    notifier.addUserMessage('who are you');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('who are you'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 35));
  });
}
