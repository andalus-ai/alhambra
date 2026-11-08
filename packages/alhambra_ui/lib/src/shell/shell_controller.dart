import 'package:flutter/foundation.dart';
import 'shell_state.dart';

/// State controller for the shell, providing observable mutations.
class ShellController extends ChangeNotifier {
  ShellState _state;

  ShellController([ShellState initialState = const ShellState()]) : _state = initialState;

  ShellState get state => _state;

  void selectIndex(int index) {
    if (_state.selectedIndex == index) return;
    _state = _state.copyWith(selectedIndex: index);
    notifyListeners();
  }

  void toggleSidebar() {
    _state = _state.copyWith(isSidebarExpanded: !_state.isSidebarExpanded);
    notifyListeners();
  }

  void toggleSearch([bool? open]) {
    _state = _state.copyWith(isSearchOpen: open ?? !_state.isSearchOpen);
    notifyListeners();
  }
}
