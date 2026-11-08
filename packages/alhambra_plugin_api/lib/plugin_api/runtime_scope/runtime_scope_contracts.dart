sealed class ScopeId {
  String get value;
  const ScopeId();
  @override
  String toString() => value;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScopeId && runtimeType == other.runtimeType && value == other.value;
  @override
  int get hashCode => value.hashCode;
}

final class ApplicationId extends ScopeId {
  @override
  final String value;
  const ApplicationId([this.value = 'app.global']);
}

final class WindowId extends ScopeId {
  @override
  final String value;
  const WindowId(this.value);
}

final class WorkspaceId extends ScopeId {
  @override
  final String value;
  const WorkspaceId(this.value);
}

final class WorkbenchSessionId extends ScopeId {
  @override
  final String value;
  const WorkbenchSessionId(this.value);
}

final class PluginInstanceId extends ScopeId {
  @override
  final String value;
  const PluginInstanceId(this.value);
}

final class ViewInstanceId extends ScopeId {
  @override
  final String value;
  const ViewInstanceId(this.value);
}

enum ScopeState {
  active,
  disposing,
  disposed,
}

enum ServiceLifetime {
  application,
  window,
  workspace,
  plugin,
  view,
}

final class ServiceKey<T> {
  final String id;
  const ServiceKey(this.id);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceKey && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ServiceKey<$T>($id)';
}

abstract interface class ServiceScope {
  T? read<T>(ServiceKey<T> key);
  T readRequired<T>(ServiceKey<T> key);
}

abstract interface class RuntimeScope {
  ScopeId get id;
  RuntimeScope? get parent;
  ScopeState get state;
  ServiceScope get services;
  Future<void> dispose();
}

class ScopeDiagnosticContext {
  final ApplicationId? applicationId;
  final WindowId? windowId;
  final WorkspaceId? workspaceId;
  final PluginInstanceId? pluginId;
  final ViewInstanceId? viewId;

  const ScopeDiagnosticContext({
    this.applicationId,
    this.windowId,
    this.workspaceId,
    this.pluginId,
    this.viewId,
  });

  @override
  String toString() =>
      'ScopeDiagnosticContext(app: $applicationId, window: $windowId, workspace: $workspaceId, plugin: $pluginId, view: $viewId)';
}

abstract interface class StatePersistence<T> {
  Future<T?> load();
  Future<void> save(T state);
}
