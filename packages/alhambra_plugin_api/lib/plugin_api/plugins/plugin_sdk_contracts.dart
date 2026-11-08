import 'dart:async';
import '../capabilities/capabilities_models.dart';
import '../runtime_scope/runtime_scope_contracts.dart';

final class PluginId {
  final String value;

  const PluginId(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PluginId && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class PluginIdentity {
  final PluginId id;
  final String version;
  final String? displayName;
  final String? publisher;

  const PluginIdentity({
    required this.id,
    required this.version,
    this.displayName,
    this.publisher,
  });
}

final class PluginManifest {
  final PluginId id;
  final String name;
  final String version;
  final String? description;
  final List<CapabilityRequest> capabilities;
  final Map<String, String> dependencies;

  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    this.description,
    this.capabilities = const [],
    this.dependencies = const {},
  });
}

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

abstract class PluginLogger {
  void log(LogLevel level, String message, [Map<String, Object?>? metadata]);
  void debug(String message) => log(LogLevel.debug, message);
  void info(String message) => log(LogLevel.info, message);
  void warning(String message) => log(LogLevel.warning, message);
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      log(LogLevel.error, message, {
        if (error != null) 'error': error.toString(),
        if (stackTrace != null) 'stackTrace': stackTrace.toString(),
      });
  void exception(Object error, StackTrace stackTrace);
}

abstract interface class PluginStorage {
  Future<String?> readString(String key);
  Future<void> writeString(String key, String value);
  Future<void> delete(String key);
  Future<void> clear();
}

final class ViewId {
  final String value;

  const ViewId(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewId && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

abstract interface class ViewContext {
  ViewInstanceId get instanceId;
  ViewId get viewId;
  WorkspaceId? get workspaceId;
  WindowId? get windowId;
  PluginIdentity get plugin;
}

abstract interface class ViewInstance {
  ViewInstanceId get id;
  Future<void> dispose();
}

abstract interface class ViewDefinition {
  ViewId get id;
  String get title;
  ViewInstance create(ViewContext context);
}

class CancellationToken {
  bool _isCancelled = false;
  final _controller = StreamController<void>.broadcast();

  bool get isCancelled => _isCancelled;
  Stream<void> get onCancelled => _controller.stream;

  void cancel() {
    if (!_isCancelled) {
      _isCancelled = true;
      _controller.add(null);
      _controller.close();
    }
  }
}
