import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import '../workbench_area.dart';
import '../../extension_region_host.dart';

class MainPaneSlot extends ConsumerWidget {
  const MainPaneSlot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Expanded(
      child: WorkbenchArea(
        area: ViewArea.main,
        fallback: const ExtensionRegionHost(
          region: UiRegion.mainWorkbench,
        ),
      ),
    );
  }
}
