/// Alhambra Identity — identity, organization, access control, and
/// repository contracts for the Alhambra Platform.
///
/// This package is deliberately infrastructure-free: it contains only
/// domain models and interfaces. Implementations (OAuth, local DB, REST)
/// live in separate packages that depend on this one.
///
/// Dependency: `alhambra_core` (pure Dart, no Flutter).
library alhambra_identity;

// Identity
export 'src/identity/user.dart';
export 'src/identity/principal.dart';
export 'src/identity/session.dart';
export 'src/identity/identity_provider.dart';
export 'src/identity/delegated_execution_context.dart';

// Organization
export 'src/organization/organization.dart';
export 'src/organization/team.dart';
export 'src/organization/membership.dart';
export 'src/organization/organization_context.dart';

// Access control
export 'src/access/permission.dart';
export 'src/access/role.dart';
export 'src/access/resource.dart';
export 'src/access/scope.dart';
export 'src/access/authorization.dart';

// Policy & Evaluation
export 'src/policy/authorization_policy.dart';
export 'src/policy/policy_evaluator.dart';

// Repository contracts
export 'src/repository/user_repository.dart';
export 'src/repository/organization_repository.dart';
export 'src/repository/membership_repository.dart';
export 'src/repository/role_repository.dart';
export 'src/repository/permission_repository.dart';

// Services
export 'src/service/organization_service.dart';
export 'src/service/membership_service.dart';
export 'src/service/authorization_service.dart';
