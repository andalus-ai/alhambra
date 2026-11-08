import 'tree/split_direction.dart';

abstract class WorkbenchRegion {
  String get id;
  const WorkbenchRegion();
}

class ViewGroupRegion extends WorkbenchRegion {
  @override
  final String id;
  final String groupId;
  final List<String> viewIds;
  final String? activeViewId;

  const ViewGroupRegion({
    required this.id,
    required this.groupId,
    required this.viewIds,
    this.activeViewId,
  });
}

class SplitRegion extends WorkbenchRegion {
  @override
  final String id;
  final SplitDirection direction;
  final double ratio;
  final WorkbenchRegion first;
  final WorkbenchRegion second;

  const SplitRegion({
    required this.id,
    required this.direction,
    required this.ratio,
    required this.first,
    required this.second,
  });
}

class PlaceholderRegion extends WorkbenchRegion {
  @override
  final String id;
  final String message;

  const PlaceholderRegion({
    required this.id,
    required this.message,
  });
}
