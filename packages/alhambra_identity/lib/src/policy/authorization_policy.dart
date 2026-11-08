import '../access/authorization.dart';

/// The intended outcome of an authorization policy rule.
enum PolicyEffect {
  allow,
  deny,
}

/// Contract for declarative or programmatic identity authorization policies.
abstract interface class AuthorizationPolicy {
  /// Unique identifier of the policy.
  String get id;

  /// Human-readable policy name.
  String get name;

  /// The effect produced if this policy matches ([PolicyEffect.allow] or [PolicyEffect.deny]).
  PolicyEffect get effect;

  /// Evaluates whether this policy applies to the given [request].
  bool evaluate(AuthorizationRequest request);
}

/// Programmatic implementation of [AuthorizationPolicy] using a predicate closure.
final class FunctionalAuthorizationPolicy implements AuthorizationPolicy {
  @override
  final String id;
  @override
  final String name;
  @override
  final PolicyEffect effect;

  final bool Function(AuthorizationRequest request) _predicate;

  const FunctionalAuthorizationPolicy({
    required this.id,
    required this.name,
    required this.effect,
    required bool Function(AuthorizationRequest request) predicate,
  }) : _predicate = predicate;

  @override
  bool evaluate(AuthorizationRequest request) => _predicate(request);

  @override
  String toString() => 'FunctionalAuthorizationPolicy($id: $name, $effect)';
}
