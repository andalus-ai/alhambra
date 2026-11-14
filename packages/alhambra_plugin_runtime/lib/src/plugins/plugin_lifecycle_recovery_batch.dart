import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

enum PluginLifecycleRecoveryExecutionAction {
  resumeStartup,
  compensateShutdown,
}

class PluginLifecycleRecoveryExecutionRequest {
  final String pluginId;
  final String expectedOperationId;
  final int expectedSequence;
  final String newOperationId;
  final PluginLifecycleRecoveryExecutionAction action;

  const PluginLifecycleRecoveryExecutionRequest({
    required this.pluginId,
    required this.expectedOperationId,
    required this.expectedSequence,
    required this.newOperationId,
    required this.action,
  });
}

/// Immutable request to recover a selected set of plugins as one dependency
/// ordered batch. The caller explicitly chooses the recovery targets.
class PluginLifecycleRecoveryBatchRequest {
  final List<String> pluginIds;
  final PluginLifecycleRecoveryExecutionAction action;
  final Map<String, AlhambraPlugin> compiledPlugins;
  final String Function(String pluginId) operationIdFactory;

  PluginLifecycleRecoveryBatchRequest({
    required Iterable<String> pluginIds,
    required this.action,
    this.compiledPlugins = const {},
    required this.operationIdFactory,
  }) : pluginIds = List<String>.unmodifiable(pluginIds);
}

