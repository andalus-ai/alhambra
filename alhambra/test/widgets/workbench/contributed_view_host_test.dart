import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_extension/alhambra_extension.dart';
import 'package:alhambra/core/license/license_service.dart';
import 'package:alhambra/core/license/edition.dart';
import 'package:alhambra/widgets/workbench/contributed_view_host.dart';
import 'package:alhambra/widgets/workbench/views/placeholders.dart';
import 'package:alhambra/providers/module_manager_provider.dart';

class _TestCommunityLicenseNotifier extends LicenseNotifier {
  @override
  LicenseInfo build() => const LicenseInfo(edition: AlhambraEdition.community);
}

void main() {
  group('ContributedViewHost & Placeholders Widget Tests', () {
    testWidgets('Renders ActivePluginView when view is available', (tester) async {
      final runtime = ExtensionRuntime();
      runtime.views.register(ViewContribution(
        id: 'test.active.view',
        ownerId: 'test.plugin',
        title: 'Active Test View',
        builder: (_) => const Text('Active View Content'),
      ));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            extensionRuntimeProvider.overrideWithValue(runtime),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ContributedViewHost(viewId: 'test.active.view'),
            ),
          ),
        ),
      );

      expect(find.text('Active View Content'), findsOneWidget);
    });

    testWidgets('Renders MissingViewPlaceholder with enable action when view is missing', (tester) async {
      final runtime = ExtensionRuntime();
      runtime.viewReferenceStore.remember(const PersistedViewReference(
        viewId: 'github.pr.review',
        title: 'GitHub PR Review',
        pluginId: 'github.plugin',
      ));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            extensionRuntimeProvider.overrideWithValue(runtime),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ContributedViewHost(viewId: 'github.pr.review'),
            ),
          ),
        ),
      );

      expect(find.byType(MissingViewPlaceholder), findsOneWidget);
      expect(find.text('GitHub PR Review'), findsOneWidget);
      expect(find.text('Enable Plugin'), findsOneWidget);
      expect(find.text('Close View'), findsOneWidget);
    });

    testWidgets('Renders UnavailableViewPlaceholder when view requires Pro/Enterprise edition', (tester) async {
      final runtime = ExtensionRuntime();
      runtime.views.register(ViewContribution(
        id: 'alhambra.pro.deepAudit',
        ownerId: 'alhambra.pro.audit',
        title: 'Deep Audit Dashboard',
        builder: (_) => const Text('Pro Content'),
      ));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            extensionRuntimeProvider.overrideWithValue(runtime),
            licenseProvider.overrideWith(() => _TestCommunityLicenseNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ContributedViewHost(viewId: 'alhambra.pro.deepAudit'),
            ),
          ),
        ),
      );

      expect(find.byType(UnavailableViewPlaceholder), findsOneWidget);
      expect(find.text('Deep Audit Dashboard'), findsOneWidget);
      expect(find.textContaining('Upgrade to Pro / Enterprise'), findsOneWidget);
    });
  });
}
