import 'dart:async';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

abstract interface class UiContributionRegistry {
  ContributionRegistration register(UiContribution contribution);
  void unregister(String contributionId);
  void unregisterOwner(String ownerId);
  Iterable<UiContribution> all();
  Iterable<UiContribution> forSurface(String surfaceId);
  Stream<String> get onSurfaceChanged;
}

class InMemoryUiContributionRegistry implements UiContributionRegistry {
  final Map<String, UiContribution> _contributions = {};
  final StreamController<String> _surfaceController =
      StreamController<String>.broadcast();

  @override
  Stream<String> get onSurfaceChanged => _surfaceController.stream;

  @override
  ContributionRegistration register(UiContribution contribution) {
    _contributions[contribution.id] = contribution;
    _surfaceController.add(contribution.surfaceId);
    return _RegistrationHandle(onDispose: () => unregister(contribution.id));
  }

  @override
  void unregister(String contributionId) {
    final removed = _contributions.remove(contributionId);
    if (removed != null) {
      _surfaceController.add(removed.surfaceId);
    }
  }

  @override
  void unregisterOwner(String ownerId) {
    final affectedSurfaces = <String>{};
    _contributions.removeWhere((id, c) {
      if (c.owner.id == ownerId) {
        affectedSurfaces.add(c.surfaceId);
        return true;
      }
      return false;
    });

    for (final surface in affectedSurfaces) {
      _surfaceController.add(surface);
    }
  }

  @override
  Iterable<UiContribution> all() => _contributions.values;

  @override
  Iterable<UiContribution> forSurface(String surfaceId) =>
      _contributions.values.where((c) => c.surfaceId == surfaceId);

  void dispose() {
    _surfaceController.close();
  }
}

class _RegistrationHandle implements ContributionRegistration {
  final void Function() onDispose;
  bool _disposed = false;

  _RegistrationHandle({required this.onDispose});

  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      onDispose();
    }
  }
}
