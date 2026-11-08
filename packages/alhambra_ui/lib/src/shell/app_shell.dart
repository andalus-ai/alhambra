import 'package:flutter/material.dart';
import '../layout/adaptive_scaffold.dart';
import '../navigation/navigation_item.dart';
import '../navigation/navigation_service.dart';
import 'shell_config.dart';
import 'shell_controller.dart';

/// The top-level application shell widget. Provides standard responsive navigation,
/// top bar, action surface, and content projection.
class AppShell extends StatefulWidget {
  final ShellConfig config;
  final ShellController? controller;
  final NavigationService? navigationService;
  final Widget child;

  const AppShell({
    super.key,
    required this.config,
    required this.child,
    this.controller,
    this.navigationService,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final ShellController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? ShellController();
    _controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  List<NavigationItem> get _flattenedItems =>
      widget.config.navigationSections.expand((s) => s.items).toList();

  void _onDestinationSelected(int index) {
    _controller.selectIndex(index);
    final items = _flattenedItems;
    if (index >= 0 && index < items.length) {
      widget.navigationService?.navigateTo(items[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _flattenedItems;

    return AdaptiveScaffold(
      items: items,
      selectedIndex: _controller.state.selectedIndex.clamp(0, items.isEmpty ? 0 : items.length - 1),
      onDestinationSelected: _onDestinationSelected,
      appBar: AppBar(
        title: Row(
          children: [
            if (widget.config.logo != null) ...[
              widget.config.logo!,
              const SizedBox(width: 8),
            ],
            Text(widget.config.title),
          ],
        ),
        actions: [
          ...widget.config.actions,
          if (widget.config.statusWidget != null) widget.config.statusWidget!,
        ],
      ),
      body: widget.child,
    );
  }
}
