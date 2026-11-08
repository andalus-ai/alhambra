import 'contribution.dart';

/// Interface for ordered contributions.
abstract interface class OrderedContribution implements OwnedContribution {
  int get order;
}

/// Utility class for ordering contributions.
class ContributionOrdering {
  /// Compare two ordered contributions.
  static int compare(OrderedContribution a, OrderedContribution b) {
    final order = a.order.compareTo(b.order);
    if (order != 0) {
      return order;
    }
    return a.id.compareTo(b.id);
  }
}
