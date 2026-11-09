import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra/layouts/layout_plugin_host.dart';

void main() {
  testWidgets('LayoutPluginHost passes ApplicationProfile to aware layouts', (tester) async {
    const profile = ApplicationProfile(
      applicationId: 'com.example.wayang',
      capabilities: {'ui.shell'},
      layoutHints: {'workflow-studio'},
    );
    final registry = LayoutPluginRegistry()
      ..register(const _ProfileAwareLayout());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          applicationProfileProvider.overrideWith((ref) => profile),
          layoutPluginRegistryProvider.overrideWith((ref) => registry),
        ],
        child: const MaterialApp(
          home: Scaffold(body: LayoutPluginHost()),
        ),
      ),
    );

    expect(find.text('com.example.wayang'), findsOneWidget);
  });

  testWidgets('LayoutPluginHost retains the legacy AppKind build adapter', (tester) async {
    final registry = LayoutPluginRegistry()
      ..register(const _LegacyLayout());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          applicationProfileProvider.overrideWith(
            (ref) => const ApplicationProfile(
              applicationId: 'com.example.legacy',
              capabilities: {'ui.shell'},
            ),
          ),
          layoutPluginRegistryProvider.overrideWith((ref) => registry),
        ],
        child: const MaterialApp(
          home: Scaffold(body: LayoutPluginHost()),
        ),
      ),
    );

    expect(find.text(AppKind.custom.name), findsOneWidget);
  });

}

final class _LegacyLayout extends LayoutPlugin {
  const _LegacyLayout();

  @override
  LayoutPluginMetadata get metadata => const LayoutPluginMetadata(
        id: 'test.legacy',
        name: 'Legacy test layout',
        description: 'Test legacy AppKind adapter.',
        icon: Icons.dashboard,
        profileRequirements: LayoutProfileRequirements(
          requiredCapabilities: {'ui.shell'},
        ),
      );

  @override
  Widget build(
    BuildContext context, {
    required ScreenClass screenClass,
    required AppKind appKind,
    required LayoutSlotConfig slots,
  }) => Text(appKind.name);
}

final class _ProfileAwareLayout extends LayoutPlugin
    implements ProfileAwareLayoutPlugin {
  const _ProfileAwareLayout();

  @override
  LayoutPluginMetadata get metadata => const LayoutPluginMetadata(
        id: 'test.profile-aware',
        name: 'Profile aware test layout',
        description: 'Test layout that reads its application profile.',
        icon: Icons.dashboard,
        profileRequirements: LayoutProfileRequirements(
          requiredCapabilities: {'ui.shell'},
        ),
      );

  @override
  Widget buildForProfile(
    BuildContext context, {
    required ScreenClass screenClass,
    required ApplicationProfile applicationProfile,
    required LayoutSlotConfig slots,
  }) {
    return Text(applicationProfile.applicationId);
  }
}
