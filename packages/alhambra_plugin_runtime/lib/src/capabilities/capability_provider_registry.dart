import 'dart:async';

import 'plugin_capability_negotiator.dart';

/// Immutable view of all registered capability providers at one revision.
final class CapabilityProviderSnapshot {
  final int revision;
  final List<PluginCapabilityDeclaration> declarations;

  CapabilityProviderSnapshot({
    required this.revision,
    required Iterable<PluginCapabilityDeclaration> declarations,
  }) : declarations = List<PluginCapabilityDeclaration>.unmodifiable(
          declarations,
        );
}

/// Runtime registry for capability declarations supplied by host components.
///
/// Registrations are grouped by owner (for example, a built-in provider
/// package). Replacing or withdrawing an owner's registration is atomic from
/// the perspective of readers: every snapshot contains either the old or the
/// new complete declaration set.
class CapabilityProviderRegistry {
  final Map<String, List<PluginCapabilityDeclaration>> _registrations = {};
  final StreamController<CapabilityProviderSnapshot> _changes =
      StreamController<CapabilityProviderSnapshot>.broadcast();

  int _revision = 0;
  bool _closed = false;

  int get revision => _revision;
  bool get isClosed => _closed;

  /// Emits a complete immutable snapshot after each successful mutation.
  Stream<CapabilityProviderSnapshot> get changes => _changes.stream;

  /// Registers declarations for [ownerId].
  ///
  /// An owner may register multiple versions of the same capability. This is
  /// useful when a host can provide multiple compatible implementations.
  /// Duplicate owner registration is rejected; use [replace] to update it.
  CapabilityProviderSnapshot register({
    required String ownerId,
    required Iterable<PluginCapabilityDeclaration> declarations,
  }) {
    _ensureOpen();
    final owner = _validateOwner(ownerId);
    if (_registrations.containsKey(owner)) {
      throw StateError('Capability provider owner "$owner" is already registered.');
    }
    final normalized = _normalize(declarations);
    _registrations[owner] = normalized;
    return _publish();
  }

  /// Atomically replaces every declaration currently registered by [ownerId].
  CapabilityProviderSnapshot replace({
    required String ownerId,
    required Iterable<PluginCapabilityDeclaration> declarations,
  }) {
    _ensureOpen();
    final owner = _validateOwner(ownerId);
    if (!_registrations.containsKey(owner)) {
      throw StateError('Capability provider owner "$owner" is not registered.');
    }
    final normalized = _normalize(declarations);
    _registrations[owner] = normalized;
    return _publish();
  }

  /// Withdraws all declarations owned by [ownerId].
  ///
  /// Returns false and leaves the revision unchanged when the owner is absent.
  bool unregister(String ownerId) {
    _ensureOpen();
    final owner = _validateOwner(ownerId);
    if (_registrations.remove(owner) == null) return false;
    _publish();
    return true;
  }

  /// Returns a stable immutable view suitable for one negotiation operation.
  CapabilityProviderSnapshot snapshot() {
    final declarations = <PluginCapabilityDeclaration>[
      for (final values in _registrations.values) ...values,
    ]..sort(_compareDeclarations);
    return CapabilityProviderSnapshot(
      revision: _revision,
      declarations: declarations,
    );
  }

  /// Releases the change stream. Existing snapshots remain valid.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _changes.close();
  }

  CapabilityProviderSnapshot _publish() {
    _revision++;
    final current = snapshot();
    _changes.add(current);
    return current;
  }

  List<PluginCapabilityDeclaration> _normalize(
    Iterable<PluginCapabilityDeclaration> declarations,
  ) {
    final result = declarations.toList(growable: false);
    for (final declaration in result) {
      if (declaration.id.value.trim().isEmpty) {
        throw ArgumentError('Capability identifiers must not be empty.');
      }
    }
    return List<PluginCapabilityDeclaration>.unmodifiable(result);
  }

  String _validateOwner(String ownerId) {
    final owner = ownerId.trim();
    if (owner.isEmpty) {
      throw ArgumentError.value(ownerId, 'ownerId', 'Must not be empty');
    }
    return owner;
  }

  void _ensureOpen() {
    if (_closed) throw StateError('CapabilityProviderRegistry is closed.');
  }

  static int _compareDeclarations(
    PluginCapabilityDeclaration a,
    PluginCapabilityDeclaration b,
  ) {
    final idOrder = a.id.value.compareTo(b.id.value);
    if (idOrder != 0) return idOrder;
    final majorOrder = a.major.compareTo(b.major);
    if (majorOrder != 0) return majorOrder;
    final minorOrder = a.minor.compareTo(b.minor);
    if (minorOrder != 0) return minorOrder;
    final patchOrder = a.patch.compareTo(b.patch);
    if (patchOrder != 0) return patchOrder;
    return a.available == b.available ? 0 : (a.available ? 1 : -1);
  }
}
