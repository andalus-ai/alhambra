import 'dock_target.dart';

abstract interface class DockTargetRegistry {
  void register(DockTarget target);
  void unregister(String groupId);
  Iterable<DockTarget> get targets;
  DockTarget? get(String groupId);
}

class InMemoryDockTargetRegistry implements DockTargetRegistry {
  final Map<String, DockTarget> _targets = {};

  @override
  void register(DockTarget target) {
    _targets[target.groupId] = target;
  }

  @override
  void unregister(String groupId) {
    _targets.remove(groupId);
  }

  @override
  Iterable<DockTarget> get targets => _targets.values;

  @override
  DockTarget? get(String groupId) => _targets[groupId];
}
