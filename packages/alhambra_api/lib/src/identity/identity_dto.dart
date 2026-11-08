/// DTO representation of a user account.
final class UserDto {
  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final Set<String> roles;

  const UserDto({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.roles = const {},
  });

  @override
  String toString() => 'UserDto($id: $email)';
}

/// DTO representation of an organization tenancy.
final class OrganizationDto {
  final String id;
  final String name;
  final String? tier;

  const OrganizationDto({
    required this.id,
    required this.name,
    this.tier,
  });

  @override
  String toString() => 'OrganizationDto($id: $name)';
}

/// DTO representation of a user session.
final class SessionDto {
  final String sessionId;
  final String userId;
  final String organizationId;
  final DateTime expiresAt;

  const SessionDto({
    required this.sessionId,
    required this.userId,
    required this.organizationId,
    required this.expiresAt,
  });
}
