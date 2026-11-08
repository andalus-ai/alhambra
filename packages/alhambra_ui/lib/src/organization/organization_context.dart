import 'package:flutter/foundation.dart';

/// Immutable value representing the currently active organization context.
final class OrganizationContext {
  final String organizationId;
  final String organizationName;

  const OrganizationContext({
    required this.organizationId,
    required this.organizationName,
  });

  @override
  bool operator ==(Object other) =>
      other is OrganizationContext &&
      other.organizationId == organizationId;

  @override
  int get hashCode => organizationId.hashCode;

  @override
  String toString() =>
      'OrganizationContext($organizationId, "$organizationName")';
}

/// Lightweight membership entry shown in the switcher dropdown.
final class OrganizationMembership {
  final String organizationId;
  final String organizationName;
  final String? avatarUrl;

  const OrganizationMembership({
    required this.organizationId,
    required this.organizationName,
    this.avatarUrl,
  });
}

/// Notifier that owns the active [OrganizationContext] and the membership list.
///
/// On [switchTo]:
/// 1. Validates membership exists.
/// 2. Updates [current].
/// 3. Increments [generationKey] — listeners (screens, caches) use this to
///    detect tenant changes and flush org-scoped state.
///
/// The [generationKey] pattern prevents stale Org-A data from appearing
/// under the Org-B header even for one frame.
class OrganizationNotifier extends ChangeNotifier {
  OrganizationContext? _current;
  List<OrganizationMembership> _memberships;
  int _generationKey = 0;

  OrganizationNotifier({
    OrganizationContext? initial,
    List<OrganizationMembership> memberships = const [],
  })  : _current = initial,
        _memberships = memberships;

  /// The active organization context, or `null` if none selected.
  OrganizationContext? get current => _current;

  /// Ordered list of organizations the user belongs to.
  List<OrganizationMembership> get memberships =>
      List.unmodifiable(_memberships);

  /// Monotonically increasing counter — changes whenever the org switches.
  ///
  /// Use as a cache buster or `key:` for subtree rebuilds:
  /// ```dart
  /// key: ValueKey(orgNotifier.generationKey),
  /// ```
  int get generationKey => _generationKey;

  /// Loads (or replaces) the membership list.
  void setMemberships(List<OrganizationMembership> memberships) {
    _memberships = List.of(memberships);
    notifyListeners();
  }

  /// Switches the active organization to [organizationId].
  ///
  /// Returns `true` on success, `false` if the id is not in [memberships].
  bool switchTo(String organizationId) {
    final match = _memberships.where(
      (m) => m.organizationId == organizationId,
    );
    if (match.isEmpty) return false;

    final membership = match.first;
    _current = OrganizationContext(
      organizationId: membership.organizationId,
      organizationName: membership.organizationName,
    );
    _generationKey++;
    notifyListeners();
    return true;
  }

  /// Clears the active organization (e.g., on logout).
  void clear() {
    _current = null;
    _generationKey++;
    notifyListeners();
  }
}
