import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

const Object _sentinel = Object();

class ViewGroupState {
  final String id;
  final ViewArea area;
  final List<String> viewIds;
  final String? activeViewId;

  const ViewGroupState({
    required this.id,
    required this.area,
    required this.viewIds,
    required this.activeViewId,
  });

  bool get isEmpty => viewIds.isEmpty;

  bool contains(String viewId) => viewIds.contains(viewId);

  ViewGroupState copyWith({
    ViewArea? area,
    List<String>? viewIds,
    Object? activeViewId = _sentinel,
  }) {
    return ViewGroupState(
      id: id,
      area: area ?? this.area,
      viewIds: viewIds ?? this.viewIds,
      activeViewId: identical(activeViewId, _sentinel)
          ? this.activeViewId
          : activeViewId as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'area': area.name,
    'viewIds': viewIds,
    if (activeViewId != null) 'activeViewId': activeViewId,
  };

  factory ViewGroupState.fromJson(Map<String, dynamic> json) => ViewGroupState(
    id: json['id'] as String,
    area: ViewArea.values.firstWhere(
      (a) => a.name == json['area'],
      orElse: () => ViewArea.main,
    ),
    viewIds: (json['viewIds'] as List<dynamic>?)?.cast<String>() ?? [],
    activeViewId: json['activeViewId'] as String?,
  );
}
