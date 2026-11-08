import 'view_behavior.dart';
import 'view_placement.dart';

/// Stable metadata descriptor for a view contribution.
class ViewDescriptor {
  final String id;
  final String title;
  final String? pluginId;
  final ViewPlacement placement;
  final ViewBehavior behavior;

  const ViewDescriptor({
    required this.id,
    required this.title,
    this.pluginId,
    this.placement = ViewPlacement.main,
    this.behavior = ViewBehavior.panel,
  });
}
