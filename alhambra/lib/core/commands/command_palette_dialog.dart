import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'package:alhambra_extension/alhambra_extension.dart';

class CommandPaletteDialog extends StatefulWidget {
  final CommandRegistry registry;

  const CommandPaletteDialog({super.key, required this.registry});

  @override
  State<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<CommandPaletteDialog> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _selectedIndex = 0;
  List<AppCommand> _filteredCommands = [];

  @override
  void initState() {
    super.initState();
    _filteredCommands = widget.registry.all;
    _queryController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _queryController.removeListener(_onSearchChanged);
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _filteredCommands = widget.registry.search(_queryController.text);
      _selectedIndex = 0;
    });
  }

  void _executeSelected() {
    if (_filteredCommands.isNotEmpty &&
        _selectedIndex < _filteredCommands.length) {
      final cmd = _filteredCommands[_selectedIndex];
      Navigator.of(context).pop();
      if (cmd.action != null) {
        cmd.action!(CommandContext(context: context));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 80, left: 40, right: 40),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 640,
        constraints: const BoxConstraints(maxHeight: 460),
        decoration: BoxDecoration(
          color: AppTheme.panel,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: AppTheme.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search Input Header
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 18, color: AppTheme.textMuted),
                  const Gap(AppSpacing.sm),
                  Expanded(
                    child: RawKeyboardListener(
                      focusNode: FocusNode(),
                      onKey: (event) {
                        if (event is RawKeyDownEvent) {
                          if (event.logicalKey ==
                              LogicalKeyboardKey.arrowDown) {
                            setState(() {
                              if (_selectedIndex <
                                  _filteredCommands.length - 1) {
                                _selectedIndex++;
                              }
                            });
                          } else if (event.logicalKey ==
                              LogicalKeyboardKey.arrowUp) {
                            setState(() {
                              if (_selectedIndex > 0) {
                                _selectedIndex--;
                              }
                            });
                          } else if (event.logicalKey ==
                              LogicalKeyboardKey.enter) {
                            _executeSelected();
                          }
                        }
                      },
                      child: TextField(
                        controller: _queryController,
                        focusNode: _focusNode,
                        autofocus: true,
                        style: AppTypography.body
                            .copyWith(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Type a command or search workspace...',
                          hintStyle: TextStyle(
                              color: AppTheme.textMuted, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ),
                  if (_queryController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear,
                          size: 16, color: AppTheme.textMuted),
                      onPressed: () => _queryController.clear(),
                    ),
                ],
              ),
            ),

            // Command Results List
            Flexible(
              child: _filteredCommands.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        'No matching commands found',
                        style:
                            TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      itemCount: _filteredCommands.length,
                      itemBuilder: (context, idx) {
                        final cmd = _filteredCommands[idx];
                        final isSelected = idx == _selectedIndex;

                        return InkWell(
                          onTap: () {
                            setState(() => _selectedIndex = idx);
                            _executeSelected();
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.sidebarSelected
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  cmd.icon,
                                  size: 16,
                                  color: isSelected
                                      ? AppTheme.accent
                                      : AppTheme.textSecondary,
                                ),
                                const Gap(AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cmd.title,
                                        style: AppTypography.body.copyWith(
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: isSelected
                                              ? AppTheme.textPrimary
                                              : AppTheme.textSecondary,
                                        ),
                                      ),
                                      if (cmd.subtitle != null)
                                        Text(
                                          cmd.subtitle!,
                                          style: AppTypography.caption.copyWith(
                                              color: AppTheme.textMuted),
                                        ),
                                    ],
                                  ),
                                ),
                                if (cmd.shortcut != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.panelAlt,
                                      borderRadius: BorderRadius.circular(4),
                                      border:
                                          Border.all(color: AppTheme.border),
                                    ),
                                    child: Text(
                                      cmd.shortcut!,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontFamily: 'monospace',
                                        color: AppTheme.textMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
