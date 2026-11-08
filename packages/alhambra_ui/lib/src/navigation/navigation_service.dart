import 'navigation_item.dart';

/// Contract for handling navigation requests from the UI.
abstract interface class NavigationService {
  /// Navigates to the destination represented by [item].
  Future<void> navigateTo(NavigationItem item);
}

/// Callback-based [NavigationService] implementation.
final class CallbackNavigationService implements NavigationService {
  final Future<void> Function(NavigationItem item) onNavigate;

  const CallbackNavigationService(this.onNavigate);

  @override
  Future<void> navigateTo(NavigationItem item) => onNavigate(item);
}
