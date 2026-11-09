import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import '../widgets/platform_breakpoints.dart';
import 'dashboard_layout.dart';
import 'mobile_layout.dart';
import 'minimal_desktop_layout.dart';

/// Open host-application descriptor. Adopters should override this provider
/// with their own application ID, capabilities, and layout hints.
final applicationProfileProvider = Provider<ApplicationProfile>((ref) {
  return const ApplicationProfile(
    applicationId: 'alhambra.generic',
    capabilities: {'ui.shell', 'ui.navigation', 'ui.responsive'},
    layoutHints: {'adaptive', 'general-purpose'},
  );
});

/// The default registry contains only broadly reusable layouts.
/// Workbench and product-specific layouts are opt-in contributions.
final layoutPluginRegistryProvider = Provider<LayoutPluginRegistry>((ref) {
  final registry = LayoutPluginRegistry()
    ..register(const MobileLayout())
    ..register(const DashboardLayout())
    ..register(const MinimalDesktopLayout());
  return registry;
});

final activeLayoutPluginProvider = Provider<LayoutPlugin>((ref) {
  final profile = ref.watch(applicationProfileProvider);
  final registry = ref.watch(layoutPluginRegistryProvider);
  final active = registry.explicitlyActive;

  // Preserve an explicitly selected layout when it supports the host profile.
  if (active != null && active.metadata.isCompatibleWith(profile)) {
    return active;
  }

  // Otherwise choose the highest-ranked compatible compiled contribution.
  final compatible = registry.all
      .where((layout) => layout.metadata.isCompatibleWith(profile))
      .toList();

  if (compatible.isEmpty) {
    throw StateError(
      'No registered layout is compatible with application '
      '${profile.applicationId}. Register a layout whose required '
      'capabilities are provided by the application.',
    );
  }

  // Preserve registration order for ties so automatic selection is stable.
  var selected = compatible.first;
  var selectedScore = selected.metadata.preferenceScore(profile);
  for (final candidate in compatible.skip(1)) {
    final score = candidate.metadata.preferenceScore(profile);
    if (score > selectedScore) {
      selected = candidate;
      selectedScore = score;
    }
  }
  return selected;
});

/// Legacy closed-category hint retained for existing layout implementations.
/// New integrations should use [applicationProfileProvider].
@Deprecated('Use applicationProfileProvider for new integrations.')
final appKindProvider = StateProvider<AppKind>((ref) => AppKind.custom);

final layoutSlotConfigProvider = Provider<LayoutSlotConfig>((ref) {
  return const LayoutSlotConfig();
});

/// Root responsive layout host. It does not import or register product UI.
class LayoutPluginHost extends ConsumerWidget {
  const LayoutPluginHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plugin = ref.watch(activeLayoutPluginProvider);
    final applicationProfile = ref.watch(applicationProfileProvider);
    // Retained only for legacy LayoutPlugin implementations.
    final appKind = ref.watch(appKindProvider);
    final slotConfig = ref.watch(layoutSlotConfigProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenClass = PlatformBreakpoints.classFor(constraints.maxWidth);
        return PlatformScreenClass(
          screenClass: screenClass,
          child: plugin is ProfileAwareLayoutPlugin
              ? plugin.buildForProfile(
                  context,
                  screenClass: screenClass,
                  applicationProfile: applicationProfile,
                  slots: slotConfig,
                )
              : plugin.build(
                  context,
                  screenClass: screenClass,
                  appKind: appKind,
                  slots: slotConfig,
                ),
        );
      },
    );
  }
}
