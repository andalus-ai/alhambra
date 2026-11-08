import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import '../extensions/contribution_registry.dart';

/// The context contributor registry is responsible for registering and managing
/// context contributors.
///
/// It is used by the context service to get the current context.
class ContextContributorRegistry
    extends ContributionRegistry<ContextContribution> {
  /// Builds the context writer.
  ///
  /// It is called by the context service to get the current context.
  void build(ContextWriter writer) {
    final contributions = getAll();
    for (final contribution in contributions) {
      try {
        contribution.contribute(writer);
      } catch (_) {}
    }
  }
}
