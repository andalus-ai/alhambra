import 'package:alhambra_core/alhambra_core.dart';

import '../identity/principal.dart';
import 'permission.dart';
import 'resource.dart';

/// A normalized authorization request.
final class AuthorizationRequest {
  final Principal principal;
  final Permission permission;
  final AccessResource resource;
  final OrganizationId? organizationId;
  final Map<String, Object?> context;

  const AuthorizationRequest({
    required this.principal,
    required this.permission,
    required this.resource,
    this.organizationId,
    this.context = const {},
  });

  @override
  String toString() =>
      'AuthorizationRequest(principal: $principal, '
      'permission: ${permission.key}, resource: $resource, org: $organizationId)';
}

/// A structured authorization decision.
final class AuthorizationDecision {
  final bool allowed;

  /// Human-readable reason for the decision, especially useful on deny.
  final String? reason;

  /// IDs of policies that matched during evaluation.
  final List<String> matchedPolicies;

  const AuthorizationDecision({
    required this.allowed,
    this.reason,
    this.matchedPolicies = const [],
  });

  /// Named constructor for an allowed decision.
  const AuthorizationDecision.allow({
    this.reason,
    this.matchedPolicies = const [],
  }) : allowed = true;

  /// Named constructor for a denied decision with a mandatory [reason].
  const AuthorizationDecision.deny(this.reason, {this.matchedPolicies = const []})
      : allowed = false;

  @override
  String toString() =>
      'AuthorizationDecision(allowed: $allowed, reason: $reason, policies: $matchedPolicies)';
}

/// Contract for evaluating authorization requests.
abstract interface class AuthorizationService {
  /// Evaluates the request and returns a full structured decision.
  Future<AuthorizationDecision> authorize(AuthorizationRequest request);

  /// Convenience method returning a boolean allowance.
  Future<bool> isAllowed(AuthorizationRequest request);
}
