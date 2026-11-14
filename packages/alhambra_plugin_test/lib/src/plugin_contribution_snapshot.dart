import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

/// Immutable counts of contributions visible through an [ExtensionRuntime].
///
/// Snapshots are intended for before/after assertions in tests. They describe
/// registry contents, not ownership, authorization, or rendered UI state.
final class PluginContributionSnapshot {
  PluginContributionSnapshot._(this.counts);

  factory PluginContributionSnapshot.capture(ExtensionRuntime runtime) {
    return PluginContributionSnapshot._(
      Map<String, int>.unmodifiable({
        'commands': runtime.commands.all.length,
        'views': runtime.views.getAll().length,
        'navigation': runtime.navigation.getAll().length,
        'settings': runtime.settings.getAll().length,
        'contextMenus': runtime.contextMenus.getAll().length,
        'toolbar': runtime.toolbar.getAll().length,
        'statusBar': runtime.statusBar.getAll().length,
        'activityBar': runtime.activityBar.getAll().length,
        'contextContributors': runtime.context.getAll().length,
      }),
    );
  }

  /// Number of registered contributions grouped by registry.
  final Map<String, int> counts;

  /// Returns the change in each registry relative to [earlier].
  Map<String, int> differenceFrom(PluginContributionSnapshot earlier) {
    return Map<String, int>.unmodifiable({
      for (final entry in counts.entries)
        entry.key: entry.value - (earlier.counts[entry.key] ?? 0),
    });
  }

  /// True when all tracked registry counts match [other].
  bool hasSameCountsAs(PluginContributionSnapshot other) {
    if (counts.length != other.counts.length) return false;
    for (final entry in counts.entries) {
      if (other.counts[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  String toString() => 'PluginContributionSnapshot($counts)';
}
