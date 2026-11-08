import '../ui/ui_location.dart';
import 'contribution_ordering.dart';

/// 
abstract interface class PlacedContribution implements OrderedContribution {
  /// 
  UiLocation get location;
}
