import 'dart:async';

import 'package:alhambra_data/alhambra_data.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// [ConnectivityMonitor] implementation backed by `connectivity_plus`.
///
/// Translates [ConnectivityResult] values from the device into the
/// platform-neutral [ConnectivityStatus] enum used across Alhambra.
///
/// Usage:
/// ```dart
/// final monitor = ConnectivityPlusMonitor();
/// monitor.status.listen((s) => print(s));
/// ```
final class ConnectivityPlusMonitor implements ConnectivityMonitor {
  final Connectivity _connectivity;
  final StreamController<ConnectivityStatus> _controller =
      StreamController<ConnectivityStatus>.broadcast();

  ConnectivityStatus _current = ConnectivityStatus.unknown;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  ConnectivityPlusMonitor([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity() {
    _start();
  }

  void _start() {
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final status = _map(results);
      if (status != _current) {
        _current = status;
        _controller.add(status);
      }
    });

    // Seed current status eagerly
    _connectivity.checkConnectivity().then((results) {
      _current = _map(results);
    });
  }

  static ConnectivityStatus _map(List<ConnectivityResult> results) {
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return ConnectivityStatus.offline;
    }
    return ConnectivityStatus.online;
  }

  @override
  Stream<ConnectivityStatus> get status => _controller.stream;

  @override
  ConnectivityStatus get currentStatus => _current;

  /// Disposes the connectivity listener and closes the stream.
  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
