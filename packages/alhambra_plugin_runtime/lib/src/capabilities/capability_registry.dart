import '../extensions/contribution_registry.dart';
import 'capability.dart';

/// The capability registry is responsible for registering and managing
/// capabilities.
///
/// It is used by the capability service to get the current context.
class CapabilityRegistry extends ContributionRegistry<CapabilityContribution> {
  /// Checks if a capability with the given ID exists.
  /// 
  /// It is called by the capability service to check if a capability exists.
  bool has(String capabilityId) => contains(capabilityId);

  /// Returns all available capabilities.
  /// 
  /// It is called by the capability service to get the current context.
  List<String> get availableCapabilities =>
      getAll().map((c) => c.id).toList();
}
