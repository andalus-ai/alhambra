import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import '../widgets/platform_breakpoints.dart';
import 'workbench_layout.dart';
import 'coding_agent_layout.dart';
import 'dashboard_layout.dart';
import 'mobile_layout.dart';
import 'minimal_desktop_layout.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Riverpod providers
// ─────────────────────────────────────────────────────────────────────────────

/// The global [LayoutPluginRegistry] with all built-in layouts pre-registered.
///
/// Override via Riverpod's `overrideWith` to supply a custom registry:
///
/// ```dart
/// ProviderScope(
///   overrides: [
///     layoutPluginRegistryProvider.overrideWith(
///       (ref) => LayoutPluginRegistry()
///         ..register(MyCustomLayout())
///         ..activate(MyCustomLayout.id),
///     ),
///   ],
///   child: const AlhambraApp(),
/// )
/// ```
final layoutPluginRegistryProvider = Provider<LayoutPluginRegistry>((ref) {
  final registry = LayoutPluginRegistry()
    ..register(const WorkbenchLayout())
    ..register(const CodingAgentLayout())
    ..register(const DashboardLayout())
    ..register(const MobileLayout())
    ..register(const MinimalDesktopLayout());
  // Default layout = Workbench
  registry.activate(WorkbenchLayout.id);
  return registry;
});

/// The currently active [LayoutPlugin].
final activeLayoutPluginProvider = Provider<LayoutPlugin>((ref) {
  final registry = ref.watch(layoutPluginRegistryProvider);
  return registry.active ?? const WorkbenchLayout();
});

/// The [AppKind] hint for the current session.
///
/// Can be overridden by the entry point or a plugin to change the semantic
/// application category (and thus how layout plugins tune themselves).
final appKindProvider = StateProvider<AppKind>((ref) => AppKind.ide);

/// The [LayoutSlotConfig] contributed by the active workspace mode or adopter.
///
/// Override this provider to inject slot-level widget builders:
///
/// ```dart
/// layoutSlotConfigProvider.overrideWith(
///   (ref) => LayoutSlotConfig({
///     LayoutSlot.sidebar: (ctx) => MyCustomSidebar(),
///   }),
/// )
/// ```
final layoutSlotConfigProvider = Provider<LayoutSlotConfig>((ref) {
  return const LayoutSlotConfig();
});

// ─────────────────────────────────────────────────────────────────────────────
// LayoutPluginHost widget
// ─────────────────────────────────────────────────────────────────────────────

/// The root layout host widget.
///
/// Placed inside [MainHomeScreen] in place of the old [WorkspaceViewHost] when
/// the layout-plugin system is active. It:
///
/// 1. Uses [LayoutBuilder] to determine the current [ScreenClass].
/// 2. Publishes the [ScreenClass] via [PlatformScreenClass] (InheritedWidget).
/// 3. Delegates building to the active [LayoutPlugin].
///
/// ### Priority chain
///
/// ```
/// WorkspaceMode.viewBuilder   (highest — custom mode overrides everything)
///       ↓
/// Active LayoutPlugin.build   (registry-based, responsive)
///       ↓
/// WorkbenchLayout (built-in fallback)
/// ```
///
/// ### Usage in `MainHomeScreen`
///
/// ```dart
/// // Replace WorkspaceViewHost() with:
/// Expanded(child: LayoutPluginHost()),
/// ```
class LayoutPluginHost extends ConsumerWidget {
  const LayoutPluginHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plugin = ref.watch(activeLayoutPluginProvider);
    final appKind = ref.watch(appKindProvider);
    final slotConfig = ref.watch(layoutSlotConfigProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenClass = PlatformBreakpoints.classFor(constraints.maxWidth);

        return PlatformScreenClass(
          screenClass: screenClass,
          child: plugin.build(
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
