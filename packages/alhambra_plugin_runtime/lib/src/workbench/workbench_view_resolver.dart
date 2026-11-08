import 'package:flutter/widgets.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import '../views/view_registry.dart';
import 'resolved_view.dart';
import 'view_error_boundary.dart';

abstract interface class ViewResolver {
  ResolvedView resolve(String viewId, [BuildContext? context]);
}

class WorkbenchViewResolver implements ViewResolver {
  final ViewRegistry viewRegistry;
  final bool isProOrHigher;
  final ViewReferenceStore? referenceStore;
  final ViewIdMigration? migration;
  final ViewAvailabilityResolver? availabilityResolver;

  const WorkbenchViewResolver({
    required this.viewRegistry,
    this.isProOrHigher = false,
    this.referenceStore,
    this.migration,
    this.availabilityResolver,
  });

  @override
  ResolvedView resolve(String viewId, [BuildContext? context]) {
    // 1. Migration check for renamed view IDs
    final effectiveViewId = migration?.migrate(viewId) ?? viewId;
    final contribution = viewRegistry.get(effectiveViewId);

    // 2. Missing view / disabled plugin
    if (contribution == null) {
      final savedRef = referenceStore?.get(effectiveViewId);
      final title = savedRef?.title ?? 'Missing View ($effectiveViewId)';

      return MissingPluginPlaceholderView(
        viewId: effectiveViewId,
        title: title,
        expectedPluginId: savedRef?.pluginId,
        reason:
            'The extension providing view "$effectiveViewId" is not installed or currently disabled.',
      );
    }

    // Remember view descriptor snapshot for future recovery if plugin unloads
    referenceStore?.remember(
      PersistedViewReference(
        viewId: effectiveViewId,
        title: contribution.title,
        pluginId: contribution.ownerId,
      ),
    );

    // 3. Custom Availability Resolver (if provided)
    if (availabilityResolver != null) {
      final availability = availabilityResolver!.resolve(
        contribution.descriptor,
      );
      if (availability is ViewUnavailable) {
        return UnavailableView(
          contribution.descriptor,
          reason: availability.reason,
        );
      } else if (availability is ViewDisabled) {
        return UnavailableView(
          contribution.descriptor,
          reason: availability.reason,
        );
      }
    }

    // 4. Entitlement check for Pro/Enterprise views
    if (contribution.ownerId.contains('.pro.') && !isProOrHigher) {
      return EnterpriseEntitlementPlaceholderView(
        viewId: effectiveViewId,
        title: contribution.title,
        featureName: contribution.title,
      );
    }

    // 5. Active valid view wrapped in error boundary (if BuildContext available)
    if (context != null) {
      return ActivePluginView(
        contribution,
        child: ViewErrorBoundary(
          viewId: effectiveViewId,
          viewTitle: contribution.title,
          builder: () => contribution.builder(context),
        ),
      );
    }

    return ActivePluginView(contribution);
  }
}
