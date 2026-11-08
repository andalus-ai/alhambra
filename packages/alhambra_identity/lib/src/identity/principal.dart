import 'package:alhambra_core/alhambra_core.dart';
import 'package:meta/meta.dart';

/// The security identity of an actor (human, agent, service, or system).
///
/// `Principal` is sealed — only the four concrete subtypes below exist in
/// this package. Application code should use exhaustive switch expressions
/// to handle each case.
@immutable
sealed class Principal {
  const Principal();
}

/// A human user principal linked to a [UserId].
final class UserPrincipal extends Principal {
  final UserId userId;

  const UserPrincipal({required this.userId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPrincipal && userId == other.userId;

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() => 'UserPrincipal($userId)';
}

/// Autonomous AI agent principal (e.g. Aljabr Coding Agent).
final class AgentPrincipal extends Principal {
  final String agentId;

  const AgentPrincipal({required this.agentId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentPrincipal && agentId == other.agentId;

  @override
  int get hashCode => agentId.hashCode;

  @override
  String toString() => 'AgentPrincipal($agentId)';
}

/// Microservice or backend subsystem principal.
final class ServicePrincipal extends Principal {
  final String serviceId;

  const ServicePrincipal({required this.serviceId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServicePrincipal && serviceId == other.serviceId;

  @override
  int get hashCode => serviceId.hashCode;

  @override
  String toString() => 'ServicePrincipal($serviceId)';
}

/// Elevated system runtime principal — no external identity required.
final class SystemPrincipal extends Principal {
  const SystemPrincipal();

  @override
  bool operator ==(Object other) => other is SystemPrincipal;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'SystemPrincipal()';
}
