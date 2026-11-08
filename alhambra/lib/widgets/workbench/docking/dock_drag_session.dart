import 'package:flutter/material.dart';
import 'dock_drag_data.dart';
import 'dock_target_registry.dart';
import 'dock_target_resolver.dart';
import 'drop_intent.dart';

class DockDragSession {
  final DockDragData data;
  final Offset globalPosition;
  final DropIntent intent;

  const DockDragSession({
    required this.data,
    required this.globalPosition,
    required this.intent,
  });
}

abstract interface class DockDragController {
  DockDragSession? get current;
  void begin(DockDragData data, Offset position);
  void update(Offset position);
  void drop();
  void cancel();
}

class DefaultDockDragController extends ChangeNotifier
    implements DockDragController {
  final DockTargetRegistry registry;
  final DockTargetResolver resolver;
  final void Function(DockDragData data, DropIntent intent)? onDrop;

  DockDragSession? _current;

  DefaultDockDragController({
    required this.registry,
    DockTargetResolver? resolver,
    this.onDrop,
  }) : resolver = resolver ?? const DockTargetResolver();

  @override
  DockDragSession? get current => _current;

  @override
  void begin(DockDragData data, Offset position) {
    final intent = resolver.resolve(
      data: data,
      position: position,
      targets: registry.targets,
    );
    _current = DockDragSession(
      data: data,
      globalPosition: position,
      intent: intent,
    );
    notifyListeners();
  }

  @override
  void update(Offset position) {
    if (_current == null) return;
    final intent = resolver.resolve(
      data: _current!.data,
      position: position,
      targets: registry.targets,
    );
    _current = DockDragSession(
      data: _current!.data,
      globalPosition: position,
      intent: intent,
    );
    notifyListeners();
  }

  @override
  void drop() {
    if (_current == null) return;
    final session = _current!;
    _current = null;
    notifyListeners();
    if (session.intent is! NoDropIntent) {
      onDrop?.call(session.data, session.intent);
    }
  }

  @override
  void cancel() {
    if (_current == null) return;
    _current = null;
    notifyListeners();
  }
}
