import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import '../capabilities/capability_engine.dart';
import '../capabilities/capability_guards.dart';

sealed class PluginStartupResult {
  final String pluginId;
  const PluginStartupResult(this.pluginId);
}

final class PluginStartupSuccess extends PluginStartupResult {
  final List<CapabilityGrant> grants;
  const PluginStartupSuccess(super.pluginId, {this.grants = const []});
}

final class PluginStartupFailure extends PluginStartupResult {
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  const PluginStartupFailure(
    super.pluginId, {
    required this.message,
    this.error,
    this.stackTrace,
  });
}

class InMemoryPluginStorage implements PluginStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> readString(String key) async => _data[key];

  @override
  Future<void> writeString(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> clear() async {
    _data.clear();
  }
}

class ScopedPluginLogger extends PluginLogger {
  final String pluginId;
  final List<String> logs = [];

  ScopedPluginLogger(this.pluginId);

  @override
  void log(LogLevel level, String message, [Map<String, Object?>? metadata]) {
    final entry = '[$level][$pluginId] $message ${metadata != null ? metadata.toString() : ''}';
    logs.add(entry);
  }

  @override
  void exception(Object error, StackTrace stackTrace) {
    log(LogLevel.error, error.toString(), {'stackTrace': stackTrace.toString()});
  }
}

class PluginStartupPipeline {
  final CapabilityResolver capabilityResolver;
  final CapabilityAuditLog? auditLog;

  const PluginStartupPipeline({
    required this.capabilityResolver,
    this.auditLog,
  });

  Future<PluginStartupResult> run({
    required AlhambraPlugin plugin,
    required PluginContext context,
    required ApplicationId applicationId,
    WindowId? windowId,
    WorkspaceId? workspaceId,
  }) async {
    final manifest = plugin.metadata;
    final policyContext = CapabilityPolicyContext(
      pluginId: manifest.id,
      pluginVersion: manifest.version,
      applicationId: applicationId,
      windowId: windowId,
      workspaceId: workspaceId,
    );

    try {
      // 1. Validate manifest
      if (manifest.id.isEmpty) {
        return const PluginStartupFailure('', message: 'Plugin ID cannot be empty');
      }

      // 2. Authorize capabilities
      final grants = <CapabilityGrant>[];
      for (final req in manifest.capabilities) {
        final request = CapabilityRequest(
          capability: req,
          requirement: CapabilityRequirement.required,
        );
        final grant = await capabilityResolver.resolve(request, policyContext);
        grants.add(grant);

        auditLog?.record(
          capability: req,
          pluginId: manifest.id,
          decision: grant.decision,
          reason: grant.reason,
        );

        if (grant.isDenied) {
          return PluginStartupFailure(
            manifest.id,
            message: 'Activation failed: Required capability "${req.value}" was denied (${grant.reason ?? 'No reason'}).',
          );
        }
      }

      // 3. Activate plugin
      await plugin.activate(context);

      return PluginStartupSuccess(manifest.id, grants: grants);
    } catch (e, st) {
      return PluginStartupFailure(
        manifest.id,
        message: 'Exception occurred during plugin activation: $e',
        error: e,
        stackTrace: st,
      );
    }
  }
}
