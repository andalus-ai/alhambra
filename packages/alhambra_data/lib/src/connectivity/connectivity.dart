import 'dart:async';
import 'connectivity_status.dart';

/// Contract for monitoring real-time network connectivity.
abstract interface class ConnectivityMonitor {
  /// Stream emitting changes in network connectivity.
  Stream<ConnectivityStatus> get status;

  /// Immediate current network connectivity status.
  ConnectivityStatus get currentStatus;
}

/// Simple controllable [ConnectivityMonitor] for tests and local runtimes.
final class SimpleConnectivityMonitor implements ConnectivityMonitor {
  ConnectivityStatus _currentStatus;
  final StreamController<ConnectivityStatus> _controller =
      StreamController<ConnectivityStatus>.broadcast();

  SimpleConnectivityMonitor({
    ConnectivityStatus initialStatus = ConnectivityStatus.online,
  }) : _currentStatus = initialStatus;

  @override
  Stream<ConnectivityStatus> get status => _controller.stream;

  @override
  ConnectivityStatus get currentStatus => _currentStatus;

  /// Updates status and notifies stream listeners.
  void setStatus(ConnectivityStatus newStatus) {
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      _controller.add(newStatus);
    }
  }

  void dispose() {
    _controller.close();
  }
}
