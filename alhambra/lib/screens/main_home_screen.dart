import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import '../core/commands/command_palette_dialog.dart';
import '../plugins/backend_monitor/providers/backend_process_provider.dart';
import '../plugins/backend_monitor/screens/backend_onboarding_dialog.dart';
import '../plugins/backend_monitor/services/backend_installer_service.dart';
import '../theme/app_colors.dart';
import '../providers/module_manager_provider.dart';

import '../widgets/app_status_bar.dart';
import '../widgets/app_toolbar.dart';
import '../layouts/layout_plugin_host.dart';

class _OpenCommandPaletteIntent extends Intent {
  const _OpenCommandPaletteIntent();
}

class _SwitchToVibeModeIntent extends Intent {
  const _SwitchToVibeModeIntent();
}

class _SwitchToIdeModeIntent extends Intent {
  const _SwitchToIdeModeIntent();
}

class _CycleWorkspaceModeIntent extends Intent {
  const _CycleWorkspaceModeIntent();
}

/// Composes the complete extensible shell:
/// Top Toolbar | WorkspaceViewHost (Custom / Generic) | Status Bar
class MainHomeScreen extends ConsumerStatefulWidget {
  const MainHomeScreen({super.key});

  @override
  ConsumerState<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends ConsumerState<MainHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBackendAndOnboard();
    });
  }

  void _openCommandPalette() {
    showDialog(
      context: context,
      builder: (context) => CommandPaletteDialog(
        registry: ref.read(commandRegistryProvider),
      ),
    );
  }

  Future<void> _checkBackendAndOnboard() async {
    try {
      final info =
          await ref.read(backendInstallerServiceProvider).detectInstallation();
      if (!info.isFullyInstalled && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const BackendOnboardingDialog(),
        );
      } else {
        ref.read(backendProcessProvider.notifier).startAll();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final modeController = ref.watch(workspaceModeControllerProvider);

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyP):
            const _OpenCommandPaletteIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyP):
            const _OpenCommandPaletteIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.alt,
            LogicalKeyboardKey.digit1): const _SwitchToVibeModeIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.alt,
            LogicalKeyboardKey.digit1): const _SwitchToVibeModeIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.alt,
            LogicalKeyboardKey.digit2): const _SwitchToIdeModeIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.alt,
            LogicalKeyboardKey.digit2): const _SwitchToIdeModeIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.alt,
            LogicalKeyboardKey.keyM): const _CycleWorkspaceModeIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.alt,
            LogicalKeyboardKey.keyM): const _CycleWorkspaceModeIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _OpenCommandPaletteIntent: CallbackAction<_OpenCommandPaletteIntent>(
            onInvoke: (intent) => _openCommandPalette(),
          ),
          _SwitchToVibeModeIntent: CallbackAction<_SwitchToVibeModeIntent>(
            onInvoke: (intent) =>
                modeController.setMode(CoreWorkspaceModes.vibe),
          ),
          _SwitchToIdeModeIntent: CallbackAction<_SwitchToIdeModeIntent>(
            onInvoke: (intent) =>
                modeController.setMode(CoreWorkspaceModes.ide),
          ),
          _CycleWorkspaceModeIntent: CallbackAction<_CycleWorkspaceModeIntent>(
            onInvoke: (intent) => modeController.cycleNextMode(),
          ),
        },
        child: const Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: AppTheme.background,
            body: Column(
              children: [
                AppToolbar(),
                Expanded(
                  child: LayoutPluginHost(),
                ),
                AppStatusBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
