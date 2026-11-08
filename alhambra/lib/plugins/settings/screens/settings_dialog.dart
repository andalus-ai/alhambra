import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_extension/alhambra_extension.dart';
import '../../../theme/app_colors.dart';

import '../../../data/backend_providers.dart';
import 'package:alhambra_coding_core/alhambra_coding_core.dart'
    show activeProjectProvider;
import '../../../providers/module_manager_provider.dart';

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  String? _currentSectionId;

  @override
  Widget build(BuildContext context) {
    final settingsRegistry = ref.watch(settingsRegistryProvider);
    final contributions = settingsRegistry.all;

    if (contributions.isEmpty) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: 920,
          height: 650,
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: const Center(
            child: Text(
              'No settings available',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ),
        ),
      );
    }

    final activeId = (_currentSectionId != null &&
            contributions.any((c) => c.id == _currentSectionId))
        ? _currentSectionId!
        : contributions.first.id;

    final activeContribution = contributions.firstWhere(
      (c) => c.id == activeId,
      orElse: () => contributions.first,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: 920,
        height: 650,
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLeftRail(contributions, activeId),
                  Container(
                    width: 1,
                    color: AppTheme.border,
                  ),
                  Expanded(
                    child: _buildSectionContent(activeContribution),
                  ),
                ],
              ),
            ),
            Container(
              height: 1,
              color: AppTheme.border,
            ),
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildLeftRail(
      List<SettingsContribution> contributions, String activeId) {
    return Container(
      width: 220,
      color: AppTheme.panel,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          for (final item in contributions)
            _NavItem(
              icon: item.icon ?? Icons.settings_outlined,
              label: item.title,
              isSelected: activeId == item.id,
              onTap: () => setState(() => _currentSectionId = item.id),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionContent(SettingsContribution activeContribution) {
    return Container(
      color: AppTheme.panelAlt,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: SingleChildScrollView(
          key: ValueKey(activeContribution.id),
          padding: const EdgeInsets.all(24),
          child: activeContribution.builder(context),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () {
              // Handle Reset to Defaults
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
            ),
            child: const Text('Reset to Defaults'),
          ),
          ElevatedButton(
            onPressed: () {
              // Handle Save/Done
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class AppearanceSettingsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Appearance'),
        _SettingsCard(
          children: [
            _DropdownTile<String>(
              title: 'Theme Mode',
              value: 'system',
              options: const ['light', 'dark', 'system'],
              onChanged: (v) {},
            ),
            _DropdownTile<String>(
              title: 'Light Theme Preset',
              value: 'defaultLight',
              options: const [
                'defaultLight',
                'solarizedLight',
                'githubLight',
                'custom'
              ],
              onChanged: (v) {},
            ),
            _DropdownTile<String>(
              title: 'Dark Theme Preset',
              value: 'defaultDark',
              options: const [
                'defaultDark',
                'dracula',
                'monokai',
                'solarizedDark',
                'custom'
              ],
              onChanged: (v) {},
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionHeader('Layout & Typography'),
        _SettingsCard(
          children: [
            _DropdownTile<String>(
              title: 'Conversation Width',
              value: 'default',
              options: const ['narrow', 'default', 'wide', 'full'],
              onChanged: (v) {},
            ),
            _SliderTile(
              title: 'Font Size',
              value: 14.0,
              min: 10,
              max: 24,
              divisions: 28,
              onChanged: (v) {},
            ),
            _ToggleTile(
              title: 'Verbose Agent Chat',
              value: false,
              onChanged: (v) {},
            ),
          ],
        ),
      ],
    );
  }
}

class AiProviderSettingsSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<AiProviderSettingsSection> createState() =>
      AiProviderSettingsSectionState();
}

class AiProviderSettingsSectionState
    extends ConsumerState<AiProviderSettingsSection> {
  String _provider = 'andalusPro';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Provider Selection'),
        _SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Primary AI Provider',
                      style: TextStyle(color: AppTheme.textPrimary)),
                  const SizedBox(height: 12),
                  _RadioGroup<String>(
                    value: _provider,
                    options: const {
                      'andalusPro': 'Andalus Pro',
                      'openai': 'OpenAI',
                      'anthropic': 'Anthropic',
                      'gemini': 'Gemini',
                      'local': 'Local LLM',
                    },
                    onChanged: (v) => setState(() => _provider = v!),
                  ),
                ],
              ),
            ),
            _TextInputTile(
              title: 'API Key',
              isObscure: true,
              hintText: 'Enter API Key for $_provider',
              onChanged: (v) {},
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionHeader('Connection Settings'),
        _SettingsCard(
          children: [
            if (_provider == 'andalusPro') ...[
              _TextInputTile(
                title: 'HTTP Base URL',
                hintText: 'https://api.andalus.dev',
                onChanged: (v) {},
              ),
              _TextInputTile(
                title: 'gRPC URL',
                hintText: 'grpc.andalus.dev:443',
                onChanged: (v) {},
              ),
            ] else ...[
              _TextInputTile(
                title: 'Base URL Override',
                hintText: 'Leave empty for default',
                onChanged: (v) {},
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        const _SectionHeader('Model Preferences'),
        _SettingsCard(
          children: [
            _TextInputTile(
              title: 'Default Model',
              hintText: 'e.g., gpt-4, claude-3-opus',
              onChanged: (v) {},
            ),
            _ToggleTile(
              title: 'Auto-select Model',
              subtitle: 'Automatically choose best model for task',
              value: true,
              onChanged: (v) {},
            ),
            _ToggleTile(
              title: 'Streaming',
              subtitle: 'Stream responses in real-time',
              value: true,
              onChanged: (v) {},
            ),
            _SliderTile(
              title: 'Max Tokens',
              value: 4096,
              min: 512,
              max: 32768,
              divisions: 63, // approx steps
              onChanged: (v) {},
            ),
            _SliderTile(
              title: 'Temperature',
              value: 0.7,
              min: 0.0,
              max: 2.0,
              divisions: 20,
              onChanged: (v) {},
            ),
            _TextInputTile(
              title: 'System Prompt',
              hintText: 'You are a helpful assistant...',
              maxLines: 4,
              onChanged: (v) {},
            ),
          ],
        ),
      ],
    );
  }
}

class LocalLlmSettingsSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<LocalLlmSettingsSection> createState() =>
      LocalLlmSettingsSectionState();
}

class LocalLlmSettingsSectionState
    extends ConsumerState<LocalLlmSettingsSection> {
  String _backend = 'gguf';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Local Inference Backend'),
        _SettingsCard(
          children: [
            _DropdownTile<String>(
              title: 'Backend',
              value: _backend,
              options: const ['gguf', 'mlx', 'llamacpp', 'ollama'],
              onChanged: (v) => setState(() => _backend = v!),
            ),
            if (_backend == 'ollama') ...[
              _TextInputTile(
                title: 'Ollama Base URL',
                hintText: 'http://localhost:11434',
                onChanged: (v) {},
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        const _SectionHeader('Model Configuration'),
        _SettingsCard(
          children: [
            _TextInputTile(
              title: 'Local Model Path',
              hintText: '/path/to/model.gguf',
              showBrowseButton: true,
              onChanged: (v) {},
            ),
            _TextInputTile(
              title: 'Local Model Name',
              hintText: 'e.g., Llama-3-8B-Instruct',
              onChanged: (v) {},
            ),
            _DropdownTile<String>(
              title: 'Context Size',
              value: '4096',
              options: const [
                '512',
                '1024',
                '2048',
                '4096',
                '8192',
                '16384',
                '32768'
              ],
              onChanged: (v) {},
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionHeader('Hardware Acceleration'),
        _SettingsCard(
          children: [
            _ToggleTile(
              title: 'GPU Enabled',
              value: true,
              onChanged: (v) {},
            ),
            _DropdownTile<String>(
              title: 'GPU Layers',
              value: '-1',
              options: const ['-1', '0', '8', '16', '32', '64'],
              onChanged: (v) {},
            ),
            _DropdownTile<String>(
              title: 'Threads',
              value: '0',
              options: const ['0', '2', '4', '8', '16'],
              onChanged: (v) {},
            ),
          ],
        ),
      ],
    );
  }
}

class AgentSecuritySettingsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Security Level'),
        _SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RadioGroup<String>(
                    value: 'standard',
                    options: const {
                      'custom': 'Custom',
                      'standard': 'Standard (Recommended)',
                      'strict': 'Strict',
                    },
                    onChanged: (v) {},
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionHeader('Execution Policies'),
        _SettingsCard(
          children: [
            _DropdownTile<String>(
              title: 'Outside Folder File Access',
              value: 'alwaysAsk',
              options: const ['alwaysAsk', 'allowAll', 'denyAll', 'allowList'],
              onChanged: (v) {},
            ),
            _DropdownTile<String>(
              title: 'Terminal Execution Policy',
              value: 'requireReview',
              options: const ['requireReview', 'autoApprove', 'autoDeny'],
              onChanged: (v) {},
            ),
            _DropdownTile<String>(
              title: 'Artifact Review Policy',
              value: 'alwaysAsk',
              options: const ['alwaysAsk', 'autoApprove', 'autoDeny'],
              onChanged: (v) {},
            ),
            _ToggleTile(
              title: 'Sandbox Mode',
              subtitle: 'Run agent tasks in isolated container',
              value: true,
              onChanged: (v) {},
            ),
          ],
        ),
      ],
    );
  }
}

class BrowserSettingsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Browser Automation'),
        _SettingsCard(
          children: [
            _DropdownTile<String>(
              title: 'JS Execution Policy',
              value: 'requestReview',
              options: const ['requestReview', 'autoApprove', 'autoDeny'],
              onChanged: (v) {},
            ),
            _ToggleTile(
              title: 'Screenshot Enabled',
              subtitle: 'Capture page state during navigation',
              value: true,
              onChanged: (v) {},
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionHeader('Browser Profile'),
        _SettingsCard(
          children: [
            _TextInputTile(
              title: 'Viewport Width',
              hintText: '1280',
              onChanged: (v) {},
            ),
            _TextInputTile(
              title: 'Viewport Height',
              hintText: '800',
              onChanged: (v) {},
            ),
            _TextInputTile(
              title: 'Download Path',
              hintText: '~/Downloads',
              showBrowseButton: true,
              onChanged: (v) {},
            ),
          ],
        ),
      ],
    );
  }
}

class NotificationsSettingsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Alerts & Sounds'),
        _SettingsCard(
          children: [
            _ToggleTile(
              title: 'Desktop Notifications',
              value: true,
              onChanged: (v) {},
            ),
            _ToggleTile(
              title: 'Sound Effects',
              value: false,
              onChanged: (v) {},
            ),
            _ToggleTile(
              title: 'Task Completion Alert',
              value: true,
              onChanged: (v) {},
            ),
            _ToggleTile(
              title: 'Error Alert',
              value: true,
              onChanged: (v) {},
            ),
          ],
        ),
      ],
    );
  }
}

class PrivacySettingsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Data & Telemetry'),
        _SettingsCard(
          children: [
            _ToggleTile(
              title: 'Telemetry Enabled',
              subtitle: 'Help improve the app by sending anonymous usage data',
              value: false,
              onChanged: (v) {},
            ),
            _ToggleTile(
              title: 'Crash Reporting',
              subtitle: 'Automatically send crash logs',
              value: true,
              onChanged: (v) {},
            ),
            _ToggleTile(
              title: 'Analytics Enabled',
              value: false,
              onChanged: (v) {},
            ),
          ],
        ),
      ],
    );
  }
}

class AdvancedSettingsSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<AdvancedSettingsSection> createState() =>
      AdvancedSettingsSectionState();
}

class AdvancedSettingsSectionState
    extends ConsumerState<AdvancedSettingsSection> {
  bool _isIndexing = false;

  Future<void> _handleIndexWorkspace() async {
    setState(() => _isIndexing = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final selectedProject = ref.read(activeProjectProvider);
      final backend = ref.read(backendServiceProvider);
      final result = await backend.indexWorkspace(
        selectedProject?.id ?? '',
        selectedProject?.rootPath,
      );

      if (result['success'] == true) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Indexed ${result['filesIndexed']} files, ${result['symbolsIndexed']} symbols, ${result['dependenciesIndexed']} dependencies in ${result['durationMs']}ms',
            ),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content:
                Text('Indexing failed: ${result['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Indexing error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isIndexing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('System'),
        _SettingsCard(
          children: [
            _DropdownTile<String>(
              title: 'Log Level',
              value: 'info',
              options: const ['debug', 'info', 'warn', 'error'],
              onChanged: (v) {},
            ),
            _ToggleTile(
              title: 'Auto Save',
              value: true,
              onChanged: (v) {},
            ),
            _TextInputTile(
              title: 'Auto Save Interval (s)',
              hintText: '60',
              onChanged: (v) {},
            ),
            _ToggleTile(
              title: 'Experimental Features',
              subtitle: 'Enable unstable features (requires restart)',
              value: false,
              onChanged: (v) {},
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton(
                onPressed: _isIndexing ? null : _handleIndexWorkspace,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: _isIndexing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Index Workspace'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionHeader('Network'),
        _SettingsCard(
          children: [
            _TextInputTile(
              title: 'Proxy URL',
              hintText: 'http://127.0.0.1:8080',
              onChanged: (v) {},
            ),
            _TextInputTile(
              title: 'No-proxy Hosts',
              hintText: 'localhost, 127.0.0.1',
              onChanged: (v) {},
            ),
            _ToggleTile(
              title: 'SSL Verification',
              value: true,
              onChanged: (v) {},
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// Helper Widgets
// ---------------------------------------------------------

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentBlue.withValues(alpha: 0.15)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? AppTheme.accentBlue : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.accentBlue : AppTheme.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color:
                    isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          final isLast = entry.key == children.length - 1;
          return Column(
            children: [
              entry.value,
              if (!isLast)
                const Divider(height: 1, thickness: 1, color: AppTheme.border),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget trailing;
  final CrossAxisAlignment crossAxisAlignment;

  const _SettingsTile({
    required this.title,
    this.subtitle,
    required this.trailing,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          trailing,
        ],
      ),
    );
  }
}

class _RadioGroup<T> extends StatelessWidget {
  final T value;
  final Map<T, String> options;
  final ValueChanged<T?> onChanged;

  const _RadioGroup({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options.entries.map((entry) {
        return RadioListTile<T>(
          title: Text(entry.value,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          value: entry.key,
          groupValue: value,
          onChanged: onChanged,
          activeColor: AppTheme.accentBlue,
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }
}

class _TextInputTile extends StatefulWidget {
  final String title;
  final String hintText;
  final bool isObscure;
  final int maxLines;
  final bool showBrowseButton;
  final ValueChanged<String> onChanged;

  const _TextInputTile({
    required this.title,
    required this.hintText,
    required this.onChanged,
    this.isObscure = false,
    this.maxLines = 1,
    this.showBrowseButton = false,
  });

  @override
  State<_TextInputTile> createState() => _TextInputTileState();
}

class _TextInputTileState extends State<_TextInputTile> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isObscure;
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      title: widget.title,
      crossAxisAlignment: widget.maxLines > 1
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      trailing: Row(
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              obscureText: _obscureText,
              maxLines: widget.maxLines,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.panelAlt,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                  borderSide: BorderSide(color: AppTheme.border),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                  borderSide: BorderSide(color: AppTheme.accentBlue),
                ),
                suffixIcon: widget.isObscure
                    ? IconButton(
                        icon: Icon(
                          _obscureText
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppTheme.textSecondary,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),
          if (widget.showBrowseButton) ...[
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                side: const BorderSide(color: AppTheme.border),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('Browse'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SliderTile extends StatefulWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  State<_SliderTile> createState() => _SliderTileState();
}

class _SliderTileState extends State<_SliderTile> {
  late double _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      title: widget.title,
      trailing: Row(
        children: [
          SizedBox(
            width: 200,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.accentBlue,
                inactiveTrackColor: AppTheme.border,
                thumbColor: AppTheme.accentBlue,
                overlayColor: AppTheme.accentBlue.withValues(alpha: 0.2),
                trackHeight: 4,
              ),
              child: Slider(
                value: _currentValue,
                min: widget.min,
                max: widget.max,
                divisions: widget.divisions,
                onChanged: (val) {
                  setState(() => _currentValue = val);
                  widget.onChanged(val);
                },
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              _currentValue.toStringAsFixed(1),
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownTile<T> extends StatelessWidget {
  final String title;
  final T value;
  final List<T> options;
  final ValueChanged<T?> onChanged;

  const _DropdownTile({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      title: title,
      trailing: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.panelAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            dropdownColor: AppTheme.panel,
            icon: const Icon(Icons.arrow_drop_down,
                color: AppTheme.textSecondary),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            onChanged: onChanged,
            items: options.map((T option) {
              return DropdownMenuItem<T>(
                value: option,
                child: Text(option.toString()),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _ToggleTile extends StatefulWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_ToggleTile> createState() => _ToggleTileState();
}

class _ToggleTileState extends State<_ToggleTile> {
  late bool _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      title: widget.title,
      subtitle: widget.subtitle,
      trailing: Switch(
        value: _currentValue,
        onChanged: (val) {
          setState(() => _currentValue = val);
          widget.onChanged(val);
        },
        activeThumbColor: Colors.white,
        activeTrackColor: AppTheme.accentBlue.withValues(alpha: 0.4),
        inactiveThumbColor: AppTheme.textSecondary,
        inactiveTrackColor: AppTheme.panelAlt,
      ),
    );
  }
}
