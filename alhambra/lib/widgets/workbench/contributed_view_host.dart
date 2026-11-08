import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import '../../core/license/license_service.dart';
import '../../providers/module_manager_provider.dart';
import 'views/placeholders.dart';

class ContributedViewHost extends ConsumerWidget {
  final String viewId;

  const ContributedViewHost({
    super.key,
    required this.viewId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(viewRegistryProvider);
    final license = ref.watch(licenseProvider);
    final referenceStore = ref.watch(viewReferenceStoreProvider);

    final resolver = WorkbenchViewResolver(
      viewRegistry: registry,
      isProOrHigher: license.edition.isProOrHigher,
      referenceStore: referenceStore,
    );

    final resolved = resolver.resolve(viewId, context);

    return switch (resolved) {
      AvailableView(child: final child) => child ?? const SizedBox.shrink(),
      MissingView(
        descriptor: final d,
        reason: final reason,
        expectedPluginId: final pId
      ) =>
        MissingViewPlaceholder(
          contextData: ViewPlaceholderContext(
            viewId: d.id,
            title: d.title,
            pluginId: pId,
            reason: reason,
          ),
        ),
      UnavailableView(
        descriptor: final d,
        reason: final reason,
        requiredEdition: final ed
      ) =>
        UnavailableViewPlaceholder(
          contextData: ViewPlaceholderContext(
            viewId: d.id,
            title: d.title,
            reason: reason,
            requiredEdition: ed,
          ),
        ),
      BrokenView(
        descriptor: final d,
        error: final err,
        stackTrace: final st,
        onRetry: final retry
      ) =>
        BrokenViewPlaceholder(
          contextData: ViewPlaceholderContext(
            viewId: d.id,
            title: d.title,
            error: err,
            stackTrace: st,
            onRetry: retry,
          ),
        ),
    };
  }
}
