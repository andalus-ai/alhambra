import 'split_direction.dart';

sealed class LayoutNode {
  final String id;

  const LayoutNode({
    required this.id,
  });

  Map<String, dynamic> toJson();

  static LayoutNode fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    if (type == 'split') {
      return SplitNode.fromJson(json);
    }
    return ViewGroupNode.fromJson(json);
  }
}

final class ViewGroupNode extends LayoutNode {
  final String groupId;

  const ViewGroupNode({
    required super.id,
    required this.groupId,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'group',
        'id': id,
        'groupId': groupId,
      };

  factory ViewGroupNode.fromJson(Map<String, dynamic> json) => ViewGroupNode(
        id: json['id'] as String,
        groupId: json['groupId'] as String,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewGroupNode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          groupId == other.groupId;

  @override
  int get hashCode => id.hashCode ^ groupId.hashCode;
}

final class SplitNode extends LayoutNode {
  final SplitDirection direction;
  final LayoutNode first;
  final LayoutNode second;
  final double ratio;

  const SplitNode({
    required super.id,
    required this.direction,
    required this.first,
    required this.second,
    this.ratio = 0.5,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'split',
        'id': id,
        'direction': direction.name,
        'ratio': ratio,
        'first': first.toJson(),
        'second': second.toJson(),
      };

  factory SplitNode.fromJson(Map<String, dynamic> json) => SplitNode(
        id: json['id'] as String,
        direction: SplitDirection.values.firstWhere(
          (d) => d.name == json['direction'],
          orElse: () => SplitDirection.horizontal,
        ),
        ratio: (json['ratio'] as num?)?.toDouble() ?? 0.5,
        first: LayoutNode.fromJson(json['first'] as Map<String, dynamic>),
        second: LayoutNode.fromJson(json['second'] as Map<String, dynamic>),
      );

  SplitNode copyWith({
    String? id,
    SplitDirection? direction,
    LayoutNode? first,
    LayoutNode? second,
    double? ratio,
  }) {
    return SplitNode(
      id: id ?? this.id,
      direction: direction ?? this.direction,
      first: first ?? this.first,
      second: second ?? this.second,
      ratio: ratio ?? this.ratio,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SplitNode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          direction == other.direction &&
          first == other.first &&
          second == other.second &&
          ratio == other.ratio;

  @override
  int get hashCode =>
      id.hashCode ^
      direction.hashCode ^
      first.hashCode ^
      second.hashCode ^
      ratio.hashCode;
}
