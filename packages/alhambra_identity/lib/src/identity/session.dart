import 'package:meta/meta.dart';

import 'principal.dart';

/// An authenticated session token binding an actor to a time-limited context.
///
/// Later consumed by `alhambra_network` to propagate authentication headers.
/// Session has no dependency on HTTP — it is purely a domain model.
@immutable
final class Session {
  final String id;
  final Principal principal;
  final DateTime expiresAt;
  final Map<String, Object?> attributes;

  const Session({
    required this.id,
    required this.principal,
    required this.expiresAt,
    this.attributes = const {},
  });

  /// Whether the session has passed its expiration threshold.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Session &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          principal == other.principal;

  @override
  int get hashCode => Object.hash(id, principal);

  @override
  String toString() => 'Session($id, expired: $isExpired)';
}
