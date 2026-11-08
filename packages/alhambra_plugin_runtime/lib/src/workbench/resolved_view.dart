import 'package:flutter/widgets.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

/// Exhaustive resolution state for a view requested by the workbench layout.
sealed class ResolvedView {
  final ViewDescriptor descriptor;
  String get viewId => descriptor.id;
  String get title => descriptor.title;

  const ResolvedView(this.descriptor);
}

class AvailableView extends ResolvedView {
  final ViewContribution contribution;
  final Widget? child;

  AvailableView(this.contribution, {this.child})
    : super(contribution.descriptor);
}

class MissingView extends ResolvedView {
  final String reason;
  final String? expectedPluginId;

  const MissingView(
    super.descriptor, {
    this.expectedPluginId,
    this.reason = 'The extension providing this view is not installed.',
  });
}

class UnavailableView extends ResolvedView {
  final String reason;
  final String? requiredEdition;

  const UnavailableView(
    super.descriptor, {
    required this.reason,
    this.requiredEdition,
  });
}

class BrokenView extends ResolvedView {
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;

  const BrokenView(
    super.descriptor, {
    required this.error,
    this.stackTrace,
    this.onRetry,
  });
}

// Backward compatibility subclasses
typedef ActivePluginView = AvailableView;

class MissingPluginPlaceholderView extends MissingView {
  MissingPluginPlaceholderView({
    required String viewId,
    required String title,
    String? expectedPluginId,
    String reason = 'The extension providing this view is not installed or currently disabled.',
  }) : super(
         ViewDescriptor(id: viewId, title: title, pluginId: expectedPluginId),
         expectedPluginId: expectedPluginId,
         reason: reason,
       );
}

class EnterpriseEntitlementPlaceholderView extends UnavailableView {
  final String featureName;

  EnterpriseEntitlementPlaceholderView({
    required String viewId,
    required String title,
    required this.featureName,
    String requiredEdition = 'Pro / Enterprise',
  }) : super(
         ViewDescriptor(id: viewId, title: title),
         reason: 'This view requires an active $requiredEdition license.',
         requiredEdition: requiredEdition,
       );
}

class CrashedViewBoundaryView extends BrokenView {
  CrashedViewBoundaryView({
    required String viewId,
    required String title,
    required super.error,
    super.stackTrace,
    required VoidCallback onRetry,
  }) : super(
         ViewDescriptor(id: viewId, title: title),
         onRetry: onRetry,
       );
}
