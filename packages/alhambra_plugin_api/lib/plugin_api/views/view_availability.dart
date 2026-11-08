import 'view_descriptor.dart';

/// Sealed hierarchy representing the availability status of a view.
sealed class ViewAvailabilityState {
  const ViewAvailabilityState();
}

final class ViewAvailable extends ViewAvailabilityState {
  const ViewAvailable();
}

final class ViewUnavailable extends ViewAvailabilityState {
  final String reason;
  const ViewUnavailable(this.reason);
}

final class ViewDisabled extends ViewAvailabilityState {
  final String reason;
  const ViewDisabled(this.reason);
}

/// Interface for resolving the runtime availability of a view based on permissions/edition.
abstract interface class ViewAvailabilityResolver {
  ViewAvailabilityState resolve(ViewDescriptor descriptor);
}
