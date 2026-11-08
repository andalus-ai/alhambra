import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra/layouts/dashboard_layout.dart';
import 'package:alhambra/layouts/layout_plugin_host.dart';
import 'package:alhambra/layouts/mobile_layout.dart';
import 'package:alhambra/layouts/minimal_desktop_layout.dart';

void main() {
  group('activeLayoutPluginProvider', () {
    test('ranks compatible layouts by application preference hints', () {
      final container = ProviderContainer(
        overrides: [
          applicationProfileProvider.overrideWith(
            (ref) => const ApplicationProfile(
              applicationId: 'com.example.analytics',
              capabilities: {
                'ui.shell',
                'ui.navigation',
                'ui.responsive',
                'data.visualization',
              },
              layoutHints: {'dashboard', 'dense-grid'},
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(activeLayoutPluginProvider).metadata.id,
        DashboardLayout.id,
      );
    });

    test('preserves an explicitly selected layout while it remains compatible', () {
      final registry = LayoutPluginRegistry()
        ..register(const MobileLayout())
        ..register(const DashboardLayout())
        ..register(const MinimalDesktopLayout())
        ..activate(MobileLayout.id);
      final container = ProviderContainer(
        overrides: [
          layoutPluginRegistryProvider.overrideWith((ref) => registry),
          applicationProfileProvider.overrideWith(
            (ref) => const ApplicationProfile(
              applicationId: 'com.example.analytics',
              capabilities: {
                'ui.shell',
                'ui.navigation',
                'data.visualization',
              },
              layoutHints: {'dashboard', 'dense-grid'},
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(activeLayoutPluginProvider).metadata.id,
        MobileLayout.id,
      );
    });

    test('falls back when an explicit layout is incompatible', () {
      final registry = LayoutPluginRegistry()
        ..register(const MobileLayout())
        ..register(const DashboardLayout())
        ..register(const MinimalDesktopLayout())
        ..activate(MobileLayout.id);
      final container = ProviderContainer(
        overrides: [
          layoutPluginRegistryProvider.overrideWith((ref) => registry),
          applicationProfileProvider.overrideWith(
            (ref) => const ApplicationProfile(
              applicationId: 'com.example.simple',
              capabilities: {'ui.shell'},
              layoutHints: {'minimal', 'single-column'},
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(activeLayoutPluginProvider).metadata.id,
        MinimalDesktopLayout.id,
      );
    });

    test('fails with an actionable error when no layout is compatible', () {
      final container = ProviderContainer(
        overrides: [
          applicationProfileProvider.overrideWith(
            (ref) => const ApplicationProfile(
              applicationId: 'com.example.empty',
              capabilities: {'custom.feature'},
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(activeLayoutPluginProvider),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('com.example.empty'),
          ),
        ),
      );
    });
  });
}
