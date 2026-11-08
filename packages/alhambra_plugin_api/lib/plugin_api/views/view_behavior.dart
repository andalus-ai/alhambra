class ViewBehavior {
  final bool movable;
  final bool closable;
  final bool pinnable;
  final bool reorderable;
  final bool dockable;
  final bool supportsSplit;

  const ViewBehavior({
    this.movable = true,
    this.closable = true,
    this.pinnable = false,
    this.reorderable = true,
    this.dockable = true,
    this.supportsSplit = false,
  });

  static const fixed = ViewBehavior(
    movable: false,
    closable: false,
    pinnable: false,
    reorderable: false,
    dockable: false,
    supportsSplit: false,
  );

  static const panel = ViewBehavior(
    movable: true,
    closable: true,
    pinnable: true,
    reorderable: true,
    dockable: true,
    supportsSplit: false,
  );

  static const editor = ViewBehavior(
    movable: true,
    closable: true,
    pinnable: true,
    reorderable: true,
    dockable: true,
    supportsSplit: true,
  );
}

