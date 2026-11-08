import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'scoped_service_registry.dart';

class BaseRuntimeScope implements RuntimeScope {
  @override
  final ScopeId id;
  @override
  final RuntimeScope? parent;
  @override
  final ScopedServiceRegistry services;

  final List<RuntimeScope> _children = [];
  ScopeState _state = ScopeState.active;

  BaseRuntimeScope({
    required this.id,
    this.parent,
    ScopedServiceRegistry? serviceRegistry,
  }) : services =
           serviceRegistry ??
           InMemoryScopedServiceRegistry(parent: parent?.services);

  @override
  ScopeState get state => _state;

  bool get isActive => _state == ScopeState.active;
  bool get isDisposing => _state == ScopeState.disposing;
  bool get isDisposed => _state == ScopeState.disposed;

  List<RuntimeScope> get children => List.unmodifiable(_children);

  void addChild(RuntimeScope child) {
    if (_state != ScopeState.active) {
      throw StateError('Cannot add child to inactive scope $id');
    }
    _children.add(child);
  }

  void removeChild(RuntimeScope child) {
    _children.remove(child);
  }

  @override
  Future<void> dispose() async {
    if (_state != ScopeState.active) {
      return; // Idempotent cleanup
    }

    _state = ScopeState.disposing;

    try {
      // 1. Dispose children first (children-first lifecycle safety)
      final childrenCopy = List<RuntimeScope>.from(_children);
      for (final child in childrenCopy) {
        await child.dispose();
      }
      _children.clear();

      // 2. Clear services
      if (services is InMemoryScopedServiceRegistry) {
        (services as InMemoryScopedServiceRegistry).clear();
      }

      await disposeScope();
    } finally {
      _state = ScopeState.disposed;
    }
  }

  Future<void> disposeScope() async {}
}

class ApplicationScope extends BaseRuntimeScope {
  ApplicationScope([ApplicationId? id])
    : super(id: id ?? const ApplicationId());
}

class WindowScope extends BaseRuntimeScope {
  WindowScope({required WindowId id, required ApplicationScope parent})
    : super(id: id, parent: parent) {
    parent.addChild(this);
  }
}

class WorkspaceScope extends BaseRuntimeScope {
  WorkspaceScope({required WorkspaceId id, required RuntimeScope parent})
    : super(id: id, parent: parent) {
    if (parent is BaseRuntimeScope) {
      parent.addChild(this);
    }
  }
}

class WorkbenchSession extends BaseRuntimeScope {
  final WindowId windowId;
  final WorkspaceId workspaceId;

  WorkbenchSessionId get sessionId => id as WorkbenchSessionId;

  WorkbenchSession({
    required WorkbenchSessionId id,
    required this.windowId,
    required this.workspaceId,
    required RuntimeScope parent,
  }) : super(id: id, parent: parent) {
    if (parent is BaseRuntimeScope) {
      parent.addChild(this);
    }
  }
}

class PluginScope extends BaseRuntimeScope {
  PluginScope({required PluginInstanceId id, required RuntimeScope parent})
    : super(id: id, parent: parent) {
    if (parent is BaseRuntimeScope) {
      parent.addChild(this);
    }
  }
}

class ViewScope extends BaseRuntimeScope {
  ViewScope({required ViewInstanceId id, required RuntimeScope parent})
    : super(id: id, parent: parent) {
    if (parent is BaseRuntimeScope) {
      parent.addChild(this);
    }
  }
}
