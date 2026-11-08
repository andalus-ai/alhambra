import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'context_contributor_registry.dart';

/// The context service is responsible for providing context to views.
/// It is a singleton that is initialized by the plugin host.
/// It is used by views to get the current context.
class ContextService {
  /// The context contributor registry.
  final ContextContributorRegistry registry;

  /// Creates a new context service.
  const ContextService({required this.registry});

  /// Returns a snapshot of the current context.
  /// It is called by views to get the current context.
  ContextSnapshot snapshot() {
    final builder = ContextBuilder();
    registry.build(builder);
    return builder.build();
  }
}
