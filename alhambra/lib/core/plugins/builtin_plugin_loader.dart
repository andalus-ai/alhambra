import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import '../commands/workbench_commands.dart';

/// A plugin activation failure captured during a startup pass.
class PluginLoadFailure {
  final String pluginId;
  final Object error;
  final StackTrace stackTrace;

  const PluginLoadFailure({
    required this.pluginId,
    required this.error,
    required this.stackTrace,
  });
}

/// Outcome of one explicit plugin-bundle activation pass.
class PluginLoadReport {
  final List<String> activatedPluginIds;
  final List<PluginLoadFailure> failures;

  PluginLoadReport({
    required List<String> activatedPluginIds,
    required List<PluginLoadFailure> failures,
  })  : activatedPluginIds = List.unmodifiable(activatedPluginIds),
        failures = List.unmodifiable(failures);

  bool get hasFailures => failures.isNotEmpty;
  bool get isSuccessful => failures.isEmpty;
}

/// Reports an activation failure without hiding it from the host application.
typedef PluginLoadErrorHandler = void Function(
  AlhambraPlugin plugin,
  Object error,
  StackTrace stackTrace,
);

/// Activates only the plugin contributions explicitly supplied by the host.
///
/// This class intentionally imports no built-in or product-specific plugins.
/// That keeps the reusable loader independent of any one application bundle
/// and lets Flutter's tree shaker omit plugin implementations the host does
/// not import.
class BuiltInPluginLoader {
  final PluginManager pluginManager;
  final List<AlhambraPlugin> platformPlugins;
  final List<AlhambraPlugin> domainPluginPacks;
  final PluginLoadErrorHandler? onPluginError;

  BuiltInPluginLoader({
    required this.pluginManager,
    List<AlhambraPlugin> platformPlugins = const [],
    List<AlhambraPlugin> domainPluginPacks = const [],
    this.onPluginError,
  })  : platformPlugins = List.unmodifiable(platformPlugins),
        domainPluginPacks = List.unmodifiable(domainPluginPacks);

  /// Activates platform contributions, then host-selected domain packs.
  ///
  /// A failure in one plugin does not prevent independent plugins from
  /// activating. Every failure is returned in [PluginLoadReport] and sent to
  /// [onPluginError] when supplied.
  Future<PluginLoadReport> loadAll() async {
    final activated = <String>[];
    final failures = <PluginLoadFailure>[];

    for (final plugin in [...platformPlugins, ...domainPluginPacks]) {
      try {
        await pluginManager.activate(plugin);
        activated.add(plugin.metadata.id);
      } catch (error, stackTrace) {
        final failure = PluginLoadFailure(
          pluginId: plugin.metadata.id,
          error: error,
          stackTrace: stackTrace,
        );
        failures.add(failure);
        onPluginError?.call(plugin, error, stackTrace);
      }
    }

    WorkbenchCommands.registerAll(
      commandRegistry: pluginManager.runtime.commands,
      workbench: pluginManager.runtime.workbench,
      workspaceModeController: pluginManager.runtime.workspaceModeController,
    );

    return PluginLoadReport(
      activatedPluginIds: activated,
      failures: failures,
    );
  }
}
