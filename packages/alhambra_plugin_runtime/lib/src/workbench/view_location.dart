import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

/// Represents the location of a view within the workbench layout.
///
/// A [ViewLocation] consists of three parts:
/// - [viewId]: The unique identifier of the view
/// - [area]: The primary area where the view is located (e.g., [ViewArea.main])
/// - [groupId]: An optional identifier for groups of views (used for split views)
///
/// This class provides methods for:
/// - Creating a [ViewLocation] instance from JSON
/// - Converting a [ViewLocation] instance to JSON
/// - Copying a [ViewLocation] instance with optional modifications
///
/// Example usage:
/// ```dart
/// final location = ViewLocation(
///   viewId: 'explorer',
///   area: ViewArea.left,
///   groupId: 'sidebar',
/// );
///
/// final json = location.toJson();
/// final fromJson = ViewLocation.fromJson(json);
///
/// final movedLocation = location.copyWith(area: ViewArea.bottom);
/// ```
///
/// See also:
/// - [ViewArea]: Enum representing the available workbench areas
/// - [View]: Base class for all views
/// - [WorkbenchViewRegistry]: Registry for managing views
/// - [PluginHost]: Main plugin host for managing plugins
class ViewLocation {
  final String viewId;
  final ViewArea area;
  final String? groupId;

  const ViewLocation({required this.viewId, required this.area, this.groupId});

  ViewLocation copyWith({ViewArea? area, String? groupId}) {
    return ViewLocation(
      viewId: viewId,
      area: area ?? this.area,
      groupId: groupId ?? this.groupId,
    );
  }

  Map<String, dynamic> toJson() => {
    'viewId': viewId,
    'area': area.name,
    if (groupId != null) 'groupId': groupId,
  };

  factory ViewLocation.fromJson(Map<String, dynamic> json) {
    return ViewLocation(
      viewId: json['viewId'] as String,
      area: ViewArea.values.firstWhere(
        (a) => a.name == json['area'],
        orElse: () => ViewArea.main,
      ),
      groupId: json['groupId'] as String?,
    );
  }
}
