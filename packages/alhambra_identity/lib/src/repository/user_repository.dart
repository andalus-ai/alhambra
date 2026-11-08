import 'package:alhambra_core/alhambra_core.dart';

import '../identity/user.dart';

/// Read-only contract for user persistence.
///
/// Implementations live outside this package (REST, local DB, etc.).
abstract interface class UserRepository {
  /// Returns the [User] with the given [id], or `null` if not found.
  Future<User?> getById(UserId id);

  /// Returns the [User] with the given [email], or `null` if not found.
  Future<User?> getByEmail(String email);

  /// Returns all users visible to the caller.
  Future<List<User>> list();
}
