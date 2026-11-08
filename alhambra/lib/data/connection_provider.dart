import 'package:flutter_riverpod/legacy.dart';

/// Mirrors the states a real connection to the agent backend (WebSocket/SSE)
/// would report. The app starts "connecting", flips to "connected" shortly
/// after, and exposes [simulateHiccup] purely so the UI states are visible
/// without needing an actual flaky network to demo them.
enum ConnectionStatus { connecting, connected, reconnecting, offline }

class ConnectionNotifier extends StateNotifier<ConnectionStatus> {
  ConnectionNotifier() : super(ConnectionStatus.connecting) {
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) state = ConnectionStatus.connected;
    });
  }

  /// Demo-only affordance: simulates a brief drop and automatic recovery,
  /// the way a real client would handle a WebSocket blip. Tapping the
  /// indicator while connected triggers this so all four states are
  /// reachable without an actual unstable network.
  Future<void> simulateHiccup() async {
    if (state != ConnectionStatus.connected) return;
    state = ConnectionStatus.reconnecting;
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    state = ConnectionStatus.connected;
  }

  Future<void> retry() async {
    if (state != ConnectionStatus.offline) return;
    state = ConnectionStatus.reconnecting;
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    state = ConnectionStatus.connected;
  }
}

final connectionStatusProvider =
    StateNotifierProvider<ConnectionNotifier, ConnectionStatus>(
  (ref) => ConnectionNotifier(),
);
