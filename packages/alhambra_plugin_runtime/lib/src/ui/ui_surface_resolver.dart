import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'ui_contribution_policy.dart';
import 'ui_contribution_registry.dart';

abstract interface class UiSurfaceResolver {
  List<UiContribution> resolve({
    required String surfaceId,
    required UiContributionContext context,
  });
}

class DefaultUiSurfaceResolver implements UiSurfaceResolver {
  final UiContributionRegistry registry;
  final UiContributionPolicy policy;

  const DefaultUiSurfaceResolver({
    required this.registry,
    this.policy = const DefaultUiContributionPolicy(),
  });

  @override
  List<UiContribution> resolve({
    required String surfaceId,
    required UiContributionContext context,
  }) {
    final raw = registry.forSurface(surfaceId);
    final filtered = <UiContribution>[];

    for (final item in raw) {
      // 1. Scope matching
      if (!_matchesScope(item.scope, context)) {
        continue;
      }

      // 2. When predicate
      if (item.when != null && !item.when!(context)) {
        continue;
      }

      // 3. Policy filtering
      if (!policy.canRender(item, context)) {
        continue;
      }

      filtered.add(item);
    }

    // 4. Deterministic sorting
    return _sortContributions(filtered);
  }

  bool _matchesScope(UiContributionScope scope, UiContributionContext context) {
    return switch (scope) {
      GlobalUiScope() => true,
      ViewUiScope(viewId: final expectedId) =>
        expectedId == null
            ? context.activeViewId != null
            : context.activeViewId == expectedId,
      AreaUiScope(area: final expectedArea) =>
        context.activeArea == expectedArea,
      ContextUiScope(contextKey: final key) => context.values.containsKey(key),
    };
  }

  List<UiContribution> _sortContributions(List<UiContribution> items) {
    if (items.length <= 1) return items;

    final result = List<UiContribution>.from(items);

    result.sort((a, b) {
      // Priority (higher numbers first)
      if (a.order.priority != b.order.priority) {
        return b.order.priority.compareTo(a.order.priority);
      }

      // Explicit before/after relative placement
      if (a.order.before == b.id || b.order.after == a.id) {
        return -1;
      }
      if (a.order.after == b.id || b.order.before == a.id) {
        return 1;
      }

      // Deterministic fallback by id
      return a.id.compareTo(b.id);
    });

    return result;
  }
}
