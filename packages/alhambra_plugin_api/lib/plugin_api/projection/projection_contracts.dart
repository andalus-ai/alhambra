import '../runtime_scope/runtime_scope_contracts.dart';
import '../capabilities/capabilities_models.dart';

/// Base marker for all UI-projected states.
abstract interface class UiState {
  const UiState();
}

/// Standard status model for UI availability.
enum UiAvailability {
  available,
  loading,
  empty,
  unavailable,
  forbidden,
  failed,
}

/// Explicit asynchronous load state container.
sealed class LoadState<T> {
  const LoadState();
}

final class Loading<T> extends LoadState<T> {
  const Loading();
}

final class Loaded<T> extends LoadState<T> {
  final T value;
  const Loaded(this.value);
}

final class Failed<T> extends LoadState<T> {
  final Object error;
  const Failed(this.error);
}

/// UI State for contributions (menus, toolbars, buttons, status items).
final class ContributionUiState implements UiState {
  final bool visible;
  final bool enabled;
  final bool checked;
  final bool loading;
  final String? badge;
  final String? tooltip;
  final UiAvailability availability;

  const ContributionUiState({
    this.visible = true,
    this.enabled = true,
    this.checked = false,
    this.loading = false,
    this.badge,
    this.tooltip,
    this.availability = UiAvailability.available,
  });

  ContributionUiState copyWith({
    bool? visible,
    bool? enabled,
    bool? checked,
    bool? loading,
    String? badge,
    String? tooltip,
    UiAvailability? availability,
  }) {
    return ContributionUiState(
      visible: visible ?? this.visible,
      enabled: enabled ?? this.enabled,
      checked: checked ?? this.checked,
      loading: loading ?? this.loading,
      badge: badge ?? this.badge,
      tooltip: tooltip ?? this.tooltip,
      availability: availability ?? this.availability,
    );
  }
}

/// Context provided to projections to prevent unconstrained service access.
final class UiProjectionContext {
  final WorkspaceId workspaceId;
  final WindowId? windowId;
  final Set<CapabilityId> capabilities;
  final String locale;

  const UiProjectionContext({
    required this.workspaceId,
    this.windowId,
    this.capabilities = const {},
    this.locale = 'en_US',
  });
}

/// Reactive projection converting domain state into presentation UI state.
abstract interface class UiProjection<D, U extends UiState> {
  U project(D domainState, UiProjectionContext context);
}

/// Registry managing dynamic projections with owner cleanup.
abstract interface class UiProjectionRegistry {
  void register<D, U extends UiState>({
    required String id,
    required String ownerId,
    required UiProjection<D, U> projection,
  });

  UiProjection<D, U>? find<D, U extends UiState>(String id);

  void removeOwner(String ownerId);

  List<String> get registeredIds;
}
