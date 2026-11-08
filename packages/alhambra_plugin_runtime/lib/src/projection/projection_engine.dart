import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

class _ProjectionEntry<D, U extends UiState> {
  final String ownerId;
  final UiProjection<D, U> projection;

  const _ProjectionEntry({required this.ownerId, required this.projection});
}

/// Default in-memory projection registry with owner-scoped lifecycle cleanup.
class DefaultUiProjectionRegistry implements UiProjectionRegistry {
  final Map<String, _ProjectionEntry<dynamic, UiState>> _projections = {};

  @override
  void register<D, U extends UiState>({
    required String id,
    required String ownerId,
    required UiProjection<D, U> projection,
  }) {
    _projections[id] = _ProjectionEntry<D, U>(
      ownerId: ownerId,
      projection: projection,
    );
  }

  @override
  UiProjection<D, U>? find<D, U extends UiState>(String id) {
    final entry = _projections[id];
    if (entry == null) return null;
    return entry.projection as UiProjection<D, U>?;
  }

  @override
  void removeOwner(String ownerId) {
    _projections.removeWhere((_, entry) => entry.ownerId == ownerId);
  }

  @override
  List<String> get registeredIds => _projections.keys.toList(growable: false);
}

/// Standard command UI projection evaluating command availability into ContributionUiState.
class CommandUiProjection
    implements UiProjection<CommandAvailabilityResult, ContributionUiState> {
  final String? badge;
  final String? tooltip;

  const CommandUiProjection({this.badge, this.tooltip});

  @override
  ContributionUiState project(
    CommandAvailabilityResult domainState,
    UiProjectionContext context,
  ) {
    return ContributionUiState(
      visible: domainState.visible,
      enabled: domainState.enabled,
      badge: badge,
      tooltip: domainState.disabledReason ?? tooltip,
      availability: domainState.enabled
          ? UiAvailability.available
          : (domainState.visible
                ? UiAvailability.unavailable
                : UiAvailability.forbidden),
    );
  }
}
