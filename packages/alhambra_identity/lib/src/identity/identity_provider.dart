import 'principal.dart';
import 'session.dart';

/// Abstract contract for authentication mechanisms (OAuth, OIDC, JWT, Local).
abstract interface class IdentityProvider {
  /// Returns the currently active authenticated principal, or null.
  Future<Principal?> currentPrincipal();

  /// Returns the current active session, or null if unauthenticated.
  Future<Session?> currentSession();

  /// Terminates the current session.
  Future<void> signOut();
}
