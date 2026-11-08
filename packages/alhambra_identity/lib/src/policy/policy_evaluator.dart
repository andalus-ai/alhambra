import '../access/authorization.dart';
import 'authorization_policy.dart';

/// Contract for evaluating a set of authorization policies against an authorization request.
abstract interface class PolicyEvaluator {
  AuthorizationDecision evaluate({
    required AuthorizationRequest request,
    required List<AuthorizationPolicy> policies,
  });
}

/// Standard policy evaluator implementing "deny-overrides-allow" semantics with a safe default-deny.
final class DefaultPolicyEvaluator implements PolicyEvaluator {
  const DefaultPolicyEvaluator();

  @override
  AuthorizationDecision evaluate({
    required AuthorizationRequest request,
    required List<AuthorizationPolicy> policies,
  }) {
    final matchedDenies = <String>[];
    final matchedAllows = <String>[];

    for (final policy in policies) {
      if (policy.evaluate(request)) {
        if (policy.effect == PolicyEffect.deny) {
          matchedDenies.add(policy.id);
        } else {
          matchedAllows.add(policy.id);
        }
      }
    }

    // Explicit deny wins over all allows
    if (matchedDenies.isNotEmpty) {
      return AuthorizationDecision.deny(
        'Explicitly denied by policy: ${matchedDenies.join(", ")}',
        matchedPolicies: matchedDenies,
      );
    }

    if (matchedAllows.isNotEmpty) {
      return AuthorizationDecision.allow(
        reason: 'Allowed by policy: ${matchedAllows.join(", ")}',
        matchedPolicies: matchedAllows,
      );
    }

    return const AuthorizationDecision.deny(
      'No matching allow policy found (default deny)',
    );
  }
}
