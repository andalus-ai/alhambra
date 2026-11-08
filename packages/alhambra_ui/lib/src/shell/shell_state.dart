/// State for the overall application shell.
final class ShellState {
  final int selectedIndex;
  final bool isSidebarExpanded;
  final bool isSearchOpen;
  final Map<String, Object?> customState;

  const ShellState({
    this.selectedIndex = 0,
    this.isSidebarExpanded = true,
    this.isSearchOpen = false,
    this.customState = const {},
  });

  ShellState copyWith({
    int? selectedIndex,
    bool? isSidebarExpanded,
    bool? isSearchOpen,
    Map<String, Object?>? customState,
  }) {
    return ShellState(
      selectedIndex: selectedIndex ?? this.selectedIndex,
      isSidebarExpanded: isSidebarExpanded ?? this.isSidebarExpanded,
      isSearchOpen: isSearchOpen ?? this.isSearchOpen,
      customState: customState ?? this.customState,
    );
  }

  @override
  String toString() => 'ShellState(index: $selectedIndex, sidebar: $isSidebarExpanded)';
}
