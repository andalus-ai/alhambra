import 'package:alhambra_core/alhambra_core.dart';
import 'package:meta/meta.dart';

/// Generic user model decoupled from domain-specific job titles or
/// application personas.
///
/// Roles and permissions are NOT stored here — they live in [Membership]
/// and [Role] so the same user can have different capabilities in
/// different organizational contexts.
@immutable
final class User {
  final UserId id;
  final String displayName;
  final String email;
  final bool active;
  final Metadata metadata;

  const User({
    required this.id,
    required this.email,
    required this.displayName,
    this.active = true,
    this.metadata = const Metadata(),
  });

  User copyWith({
    UserId? id,
    String? email,
    String? displayName,
    bool? active,
    Metadata? metadata,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      active: active ?? this.active,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'User($id, $displayName, active: $active)';
}
