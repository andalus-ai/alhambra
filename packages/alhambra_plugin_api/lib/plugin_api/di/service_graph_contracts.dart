import 'dart:async';

import '../plugins/plugin_sdk_contracts.dart';
import '../runtime_scope/runtime_scope_contracts.dart';

/// Product edition abstraction for profile-based composition.
enum ProductEdition { community, pro, enterprise }

/// Application startup and capability profile.
final class ApplicationProfile {
  final ProductEdition edition;
  final String applicationName;
  final String version;

  const ApplicationProfile({
    required this.edition,
    this.applicationName = 'Alhambra',
    this.version = '1.0.0',
  });
}

/// Interface for objects that require explicit resource disposal.
abstract interface class ServiceDisposable {
  Future<void> dispose();
}

/// View-scoped service bundle.
final class ViewServices {
  final String workspaceId;
  final ViewInstanceId instanceId;
  final String viewDefinitionId;

  const ViewServices({
    required this.workspaceId,
    required this.instanceId,
    required this.viewDefinitionId,
  });
}

/// Workspace-scoped service bundle.
final class WorkspaceServices implements ServiceDisposable {
  final String workspaceId;
  final Map<String, Object> scopedServices;
  final StreamController<String> _eventsController =
      StreamController<String>.broadcast();

  WorkspaceServices({
    required this.workspaceId,
    Map<String, Object>? scopedServices,
  }) : scopedServices = scopedServices ?? {};

  Stream<String> get events => _eventsController.stream;
  void emit(String event) => _eventsController.add(event);

  T? get<T>(String key) => scopedServices[key] as T?;
  void put<T extends Object>(String key, T service) =>
      scopedServices[key] = service;

  @override
  Future<void> dispose() async {
    for (final service in scopedServices.values) {
      if (service is ServiceDisposable) {
        await service.dispose();
      }
    }
    await _eventsController.close();
  }
}

/// Plugin-scoped service bundle.
final class ScopedPluginServices implements ServiceDisposable {
  final String pluginId;
  final Map<String, Object> services;

  ScopedPluginServices({required this.pluginId, Map<String, Object>? services})
    : services = services ?? {};

  T? get<T>(String key) => services[key] as T?;
  void put<T extends Object>(String key, T service) => services[key] = service;

  @override
  Future<void> dispose() async {
    for (final service in services.values) {
      if (service is ServiceDisposable) {
        await service.dispose();
      }
    }
  }
}

/// Multi-workspace lifecycle orchestrator.
abstract interface class WorkspaceManager implements ServiceDisposable {
  List<String> get workspaceIds;
  String? get activeWorkspaceId;
  WorkspaceServices get(String workspaceId);
  Future<String> createWorkspace();
  Future<void> activateWorkspace(String workspaceId);
  Future<void> closeWorkspace(String workspaceId);
}

/// UI Context object passed to presentation layer root.
final class AlhambraUIContext {
  final ApplicationProfile profile;
  final WorkspaceManager workspaceManager;

  const AlhambraUIContext({
    required this.profile,
    required this.workspaceManager,
  });
}
