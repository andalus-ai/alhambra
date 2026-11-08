import 'view_area.dart';

class ViewPlacement {
  final ViewArea preferredArea;
  final String? groupId;

  const ViewPlacement({
    required this.preferredArea,
    this.groupId,
  });

  static const sidebar = ViewPlacement(
    preferredArea: ViewArea.sidebar,
  );

  static const main = ViewPlacement(
    preferredArea: ViewArea.main,
  );

  static const bottomPanel = ViewPlacement(
    preferredArea: ViewArea.bottomPanel,
  );

  static const secondaryPanel = ViewPlacement(
    preferredArea: ViewArea.secondaryPanel,
  );
}
