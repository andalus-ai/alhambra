import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'alhambra_plugin_test_host.dart';
import 'plugin_conformance_result.dart';

/// Reusable checks for the stable, public Alhambra plugin contract.
///
/// Metadata checks are side-effect free. Lifecycle checks explicitly execute
/// the supplied plugin in an isolated in-process host; only run them for
/// trusted plugin implementations.
final class PluginConformanceSuite {
  const PluginConformanceSuite();

  PluginConformanceResult validateMetadata(PluginMetadata metadata) {
    final issues = <PluginConformanceIssue>[];
    if (metadata.id.trim().isEmpty) {
      issues.add(const PluginConformanceIssue(code: 'metadata.id.empty',
          path: 'metadata.id', message: 'Plugin ID must not be empty or whitespace.'));
    } else if (metadata.id != metadata.id.trim()) {
      issues.add(const PluginConformanceIssue(code: 'metadata.id.untrimmed',
          path: 'metadata.id', message: 'Plugin ID must not contain surrounding whitespace.'));
    }
    if (metadata.name.trim().isEmpty) {
      issues.add(const PluginConformanceIssue(code: 'metadata.name.empty',
          path: 'metadata.name', message: 'Plugin display name must not be empty.'));
    }
    if (metadata.version.trim().isEmpty) {
      issues.add(const PluginConformanceIssue(code: 'metadata.version.empty',
          path: 'metadata.version', message: 'Plugin version must not be empty.'));
    }
    final seen = <String>{};
    for (var i = 0; i < metadata.capabilities.length; i++) {
      final value = metadata.capabilities[i].value;
      if (value.trim().isEmpty) {
        issues.add(PluginConformanceIssue(code: 'metadata.capability.empty',
            path: 'metadata.capabilities[$i]', message: 'Capability ID must not be empty.'));
      } else if (value != value.trim()) {
        issues.add(PluginConformanceIssue(code: 'metadata.capability.untrimmed',
            path: 'metadata.capabilities[$i]', message: 'Capability ID must not contain surrounding whitespace.'));
      } else if (!seen.add(value)) {
        issues.add(PluginConformanceIssue(code: 'metadata.capability.duplicate',
            path: 'metadata.capabilities[$i]', message: 'Capability "' + value + '" is declared more than once.'));
      }
    }
    return PluginConformanceResult(issues);
  }

  PluginConformanceResult validatePluginSet(Iterable<PluginMetadata> metadata) {
    final issues = <PluginConformanceIssue>[];
    final firstIndexById = <String, int>{};
    var index = 0;
    for (final item in metadata) {
      issues.addAll(validateMetadata(item).issues);
      final previous = firstIndexById[item.id];
      if (previous != null) {
        issues.add(PluginConformanceIssue(code: 'plugin.id.duplicate',
            path: 'plugins[$index].metadata.id',
            message: 'Plugin ID "' + item.id + '" duplicates plugins[$previous].'));
      } else {
        firstIndexById[item.id] = index;
      }
      index++;
    }
    return PluginConformanceResult(issues);
  }

  /// Runs an opt-in lifecycle round trip for a trusted plugin implementation.
  ///
  /// Verifies manager active state and aggregate contribution counts return to
  /// baseline. It cannot prove that external side effects were released.
  Future<PluginConformanceResult> verifyLifecycle(AlhambraPlugin plugin) async {
    final metadata = validateMetadata(plugin.metadata);
    if (!metadata.isConformant) return metadata;
    final host = AlhambraPluginTestHost();
    final before = host.snapshot();
    final issues = <PluginConformanceIssue>[];
    try {
      await host.activate(plugin);
      if (!host.isActive(plugin.metadata.id)) {
        issues.add(const PluginConformanceIssue(
          code: 'lifecycle.activation.not_active',
          message: 'Activation completed but manager did not mark plugin active.'));
      }
    } catch (error) {
      issues.add(PluginConformanceIssue(code: 'lifecycle.activation.failed',
          message: 'Plugin activation failed: $error'));
    }
    if (host.isActive(plugin.metadata.id)) {
      try {
        await host.deactivate(plugin.metadata.id);
      } catch (error) {
        issues.add(PluginConformanceIssue(code: 'lifecycle.deactivation.failed',
            message: 'Plugin deactivation failed: $error'));
      }
    }
    if (host.isActive(plugin.metadata.id)) {
      issues.add(const PluginConformanceIssue(code: 'lifecycle.cleanup.active',
          message: 'Plugin remained active after cleanup attempt.'));
    }
    if (!host.snapshot().hasSameCountsAs(before)) {
      issues.add(const PluginConformanceIssue(code: 'lifecycle.cleanup.contributions',
          message: 'Contribution registry counts did not return to baseline.'));
    }
    return PluginConformanceResult(issues);
  }
}
