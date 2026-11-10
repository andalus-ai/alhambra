import 'dart:async';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import '../capabilities/plugin_capability_negotiator.dart';
import '../extensions/extension_runtime.dart';
import 'runtime_plugin_context.dart';

typedef PluginCapabilityRequirementsResolver = Iterable<PluginCapabilityRequirement>
    Function(AlhambraPlugin plugin);

class PluginCapabilityNegotiationException implements Exception {
  final String pluginId;
  final CapabilityNegotiationResult result;

  const PluginCapabilityNegotiationException({
    required this.pluginId,
    required this.result,
  });

  @override
  String toString() =>
      'PluginCapabilityNegotiationException: required capabilities for '
      '"$pluginId" are incompatible.';
}

/// Manages compiled, application-selected plugins. Hosts construct plugin
/// instances; this manager never discovers or executes downloaded Dart code.
class PluginManager {
  final Map<String, AlhambraPlugin> _activePlugins = {};
  final Map<String, RuntimePluginContext> _contexts = {};
  final Map<String, CapabilityNegotiationResult> _capabilityNegotiations = {};
  final Map<String, Future<void>> _operationTails = {};

  final ExtensionRuntime runtime;
  final PluginCapabilityNegotiator? capabilityNegotiator;
  final List<PluginCapabilityDeclaration> capabilityDeclarations;
  final PluginCapabilityRequirementsResolver? capabilityRequirementsResolver;

  PluginManager({
    ExtensionRuntime? runtime,
    this.capabilityNegotiator,
    Iterable<PluginCapabilityDeclaration> capabilityDeclarations = const [],
    this.capabilityRequirementsResolver,
  })  : runtime = runtime ?? ExtensionRuntime(),
        capabilityDeclarations =
            List<PluginCapabilityDeclaration>.unmodifiable(capabilityDeclarations) {
    if ((capabilityNegotiator == null) !=
        (capabilityRequirementsResolver == null)) {
      throw ArgumentError(
        'capabilityNegotiator and capabilityRequirementsResolver must be provided together.',
      );
    }
  }

  /// Activates once. Negotiation runs before plugin code and never grants
  /// permissions; the capability broker remains the authorization boundary.
  Future<void> activate(AlhambraPlugin plugin) {
    final pluginId = plugin.metadata.id;
    if (pluginId.trim().isEmpty) {
      return Future<void>.error(
        ArgumentError.value(pluginId, 'plugin.metadata.id', 'Must not be empty'),
      );
    }

    return _serialize(pluginId, () async {
      if (_activePlugins.containsKey(pluginId)) return;
      _negotiateCapabilities(plugin);
      final context = RuntimePluginContext(pluginId: pluginId, runtime: runtime);

      try {
        await plugin.activate(context);
        runtime.validator.validateOwner(pluginId);
        _activePlugins[pluginId] = plugin;
        _contexts[pluginId] = context;
      } catch (error, stackTrace) {
        try {
          _unregisterContributions(pluginId);
        } catch (_) {
          // Preserve the activation failure.
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
    });
  }

  void _negotiateCapabilities(AlhambraPlugin plugin) {
    final negotiator = capabilityNegotiator;
    final resolver = capabilityRequirementsResolver;
    if (negotiator == null || resolver == null) return;

    final result = negotiator.negotiate(
      requirements: resolver(plugin),
      declarations: capabilityDeclarations,
    );
    _capabilityNegotiations[plugin.metadata.id] = result;
    if (!result.canActivate) {
      throw PluginCapabilityNegotiationException(
        pluginId: plugin.metadata.id,
        result: result,
      );
    }
  }

  /// Most recent negotiation outcomes, including failed pre-activation checks.
  Map<String, CapabilityNegotiationResult> get capabilityNegotiations =>
      Map<String, CapabilityNegotiationResult>.unmodifiable(
        _capabilityNegotiations,
      );

  /// Deactivates a plugin and always releases host-owned resources.
  Future<void> deactivate(String pluginId) {
    return _serialize(pluginId, () async {
      final plugin = _activePlugins[pluginId];
      final context = _contexts[pluginId];
      if (plugin == null || context == null) return;

      Object? failure;
      StackTrace? failureStackTrace;
      try {
        runtime.workbench.removeViewsOwnedBy(pluginId);
        await plugin.deactivate(context);
      } catch (error, stackTrace) {
        failure = error;
        failureStackTrace = stackTrace;
      }

      try {
        _unregisterContributions(pluginId);
      } catch (error, stackTrace) {
        failure ??= error;
        failureStackTrace ??= stackTrace;
      } finally {
        _activePlugins.remove(pluginId);
        _contexts.remove(pluginId);
      }

      if (failure != null) {
        Error.throwWithStackTrace(failure, failureStackTrace!);
      }
    });
  }

  Future<T> _serialize<T>(
    String pluginId,
    Future<T> Function() operation,
  ) async {
    final previous = _operationTails[pluginId] ?? Future<void>.value();
    final completer = Completer<void>();
    final tail = completer.future;
    _operationTails[pluginId] = tail;
    try {
      await previous;
      return await operation();
    } finally {
      completer.complete();
      if (identical(_operationTails[pluginId], tail)) {
        _operationTails.remove(pluginId);
      }
    }
  }

  void _unregisterContributions(String pluginId) {
    Object? firstFailure;
    StackTrace? firstFailureStackTrace;
    for (final target in runtime.cleanupTargets) {
      try {
        target.unregisterAllForOwner(pluginId);
      } catch (error, stackTrace) {
        firstFailure ??= error;
        firstFailureStackTrace ??= stackTrace;
      }
    }
    if (firstFailure != null) {
      Error.throwWithStackTrace(firstFailure, firstFailureStackTrace!);
    }
  }

  List<AlhambraPlugin> get activePlugins =>
      List<AlhambraPlugin>.unmodifiable(_activePlugins.values);
}
