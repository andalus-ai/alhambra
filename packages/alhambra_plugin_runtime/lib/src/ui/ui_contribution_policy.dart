import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

abstract interface class UiContributionPolicy {
  bool canRender(UiContribution contribution, UiContributionContext context);
}

class DefaultUiContributionPolicy implements UiContributionPolicy {
  final bool isProOrHigher;

  const DefaultUiContributionPolicy({this.isProOrHigher = false});

  @override
  bool canRender(UiContribution contribution, UiContributionContext context) {
    if (contribution.owner.kind == ContributionOwnerKind.pro &&
        !isProOrHigher) {
      return false;
    }
    if (contribution.owner.kind == ContributionOwnerKind.enterprise &&
        !isProOrHigher) {
      return false;
    }
    return true;
  }
}
