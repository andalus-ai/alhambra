class PaneBehavior {
  final bool hideWhenEmpty;

  const PaneBehavior({
    this.hideWhenEmpty = false,
  });

  Map<String, dynamic> toJson() => {
        'hideWhenEmpty': hideWhenEmpty,
      };

  factory PaneBehavior.fromJson(Map<String, dynamic> json) => PaneBehavior(
        hideWhenEmpty: json['hideWhenEmpty'] as bool? ?? false,
      );
}

class PaneState {
  final bool visible;
  final bool collapsed;
  final double? size;

  const PaneState({
    required this.visible,
    required this.collapsed,
    this.size,
  });

  const PaneState.visible({
    this.size,
  })  : visible = true,
        collapsed = false;

  const PaneState.hidden()
      : visible = false,
        collapsed = false,
        size = null;

  const PaneState.collapsed({
    this.size,
  })  : visible = true,
        collapsed = true;

  PaneState copyWith({
    bool? visible,
    bool? collapsed,
    double? size,
  }) {
    return PaneState(
      visible: visible ?? this.visible,
      collapsed: collapsed ?? this.collapsed,
      size: size ?? this.size,
    );
  }

  Map<String, dynamic> toJson() => {
        'visible': visible,
        'collapsed': collapsed,
        if (size != null) 'size': size,
      };

  factory PaneState.fromJson(Map<String, dynamic> json) => PaneState(
        visible: json['visible'] as bool? ?? true,
        collapsed: json['collapsed'] as bool? ?? false,
        size: (json['size'] as num?)?.toDouble(),
      );
}
