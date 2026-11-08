import 'package:flutter_riverpod/legacy.dart';

/// Rolling shell output for the Terminal tab.
class TerminalLogNotifier extends StateNotifier<List<String>> {
  TerminalLogNotifier() : super(const []);

  void append(String line) => state = [...state, line];
  void clear() => state = const [];
}

final terminalLogProvider =
    StateNotifierProvider<TerminalLogNotifier, List<String>>(
  (ref) => TerminalLogNotifier(),
);
