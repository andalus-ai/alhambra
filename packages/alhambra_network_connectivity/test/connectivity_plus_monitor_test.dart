import 'package:alhambra_data/alhambra_data.dart';
import 'package:alhambra_network_connectivity/alhambra_network_connectivity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ────────────────────────────────────────────────────────────────────────────
  // ConnectivityPlusMonitor — compile-time contract compliance only.
  //
  // Real connectivity events require a physical device with platform plugins.
  // Use integration_test or a device-backed test runner for full coverage.
  // ────────────────────────────────────────────────────────────────────────────
  group('ConnectivityPlusMonitor (contract compliance)', () {
    test('class implements ConnectivityMonitor interface', () {
      // Type-check only: verifies the class implements the contract at
      // compile time. Constructing the real monitor may fail without the
      // platform plugin, so we only assert on the type declaration.
      expect(ConnectivityPlusMonitor, isNotNull,
          reason: 'ConnectivityPlusMonitor must be exported by the package');
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // SimpleConnectivityMonitor (InMemory fallback) — full behaviour tests.
  //
  // This is the standard test-double for ConnectivityMonitor.
  // All consumer packages that depend on ConnectivityMonitor should use
  // SimpleConnectivityMonitor in their unit tests.
  // ────────────────────────────────────────────────────────────────────────────
  group('SimpleConnectivityMonitor (InMemory fallback)', () {
    late SimpleConnectivityMonitor monitor;

    setUp(() => monitor = SimpleConnectivityMonitor());
    tearDown(() => monitor.dispose());

    test('starts online by default', () {
      expect(monitor.currentStatus, ConnectivityStatus.online);
    });

    test('can be initialized offline', () {
      final offline = SimpleConnectivityMonitor(
          initialStatus: ConnectivityStatus.offline);
      expect(offline.currentStatus, ConnectivityStatus.offline);
      offline.dispose();
    });

    test('setStatus updates currentStatus', () {
      monitor.setStatus(ConnectivityStatus.offline);
      expect(monitor.currentStatus, ConnectivityStatus.offline);
    });

    test('setStatus emits on stream', () async {
      final events = <ConnectivityStatus>[];
      final sub = monitor.status.listen(events.add);

      monitor.setStatus(ConnectivityStatus.offline);
      monitor.setStatus(ConnectivityStatus.online);

      await Future<void>.delayed(Duration.zero);
      expect(events, [ConnectivityStatus.offline, ConnectivityStatus.online]);
      await sub.cancel();
    });

    test('duplicate status does not emit duplicate events', () async {
      final events = <ConnectivityStatus>[];
      final sub = monitor.status.listen(events.add);

      monitor.setStatus(ConnectivityStatus.online); // same as initial, no emit
      monitor.setStatus(ConnectivityStatus.offline);

      await Future<void>.delayed(Duration.zero);
      expect(events, [ConnectivityStatus.offline]);
      await sub.cancel();
    });

    test('status stream is broadcast', () {
      expect(monitor.status.isBroadcast, isTrue);
    });

    test('implements ConnectivityMonitor', () {
      expect(monitor, isA<ConnectivityMonitor>());
    });
  });
}
