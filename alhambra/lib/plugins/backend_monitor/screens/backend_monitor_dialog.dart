import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/app_colors.dart';
import '../providers/backend_process_provider.dart';
import '../services/update_manager_service.dart';
import 'backend_onboarding_dialog.dart';

class BackendMonitorDialog extends ConsumerStatefulWidget {
  const BackendMonitorDialog({super.key});

  @override
  ConsumerState<BackendMonitorDialog> createState() =>
      _BackendMonitorDialogState();
}

class _BackendMonitorDialogState extends ConsumerState<BackendMonitorDialog> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _autoScroll = true;
  String _filterText = '';
  int _activeTopNav = 0; // 0: Dual Supervisor, 1: Update Manager

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _filterText = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backendState = ref.watch(backendProcessProvider);
    final notifier = ref.read(backendProcessProvider.notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    List<String> rawLogs;
    if (backendState.activeLogTab == 'alhambra') {
      rawLogs = backendState.alhambra.logs;
    } else if (backendState.activeLogTab == 'gollek') {
      rawLogs = backendState.gollek.logs;
    } else if (backendState.activeLogTab == 'frontend') {
      rawLogs = backendState.frontend.logs;
    } else {
      rawLogs = backendState.logs;
    }

    final filteredLogs = _filterText.isEmpty
        ? rawLogs
        : rawLogs
            .where((line) => line.toLowerCase().contains(_filterText))
            .toList();

    return Dialog(
      backgroundColor: AppTheme.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border, width: 1.2),
      ),
      child: Container(
        width: 1080,
        height: 740,
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // ── Top Header ────────────────────────────────────────────────
            _buildHeader(context, backendState, notifier),

            // ── Navigation Bar (Supervisor vs Update Manager) ─────────────
            _buildTopNavBar(),

            if (_activeTopNav == 0) ...[
              // ── Server Cards Grid (Alhambra & Gollek) ────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _ServerCard(
                        type: ServerType.gollek,
                        server: backendState.gollek,
                        bootOrderLabel: 'BOOT STEP 1',
                        icon: Icons.memory_outlined,
                        primaryPortLabel: 'gRPC :9131 / HTTP :8080',
                        features: const [
                          'Safetensor / GGUF Runner',
                          'Hardware Metal / CPU Compute',
                          'Paged KV Cache Engine',
                          'Tokenization Substrate',
                        ],
                        quickLinks: [
                          _QuickLink(
                            label: 'Models API',
                            icon: Icons.list_alt,
                            onTap: () =>
                                _launchUrl('http://localhost:8080/v1/models'),
                          ),
                          _QuickLink(
                            label: 'Engine Probe',
                            icon: Icons.speed,
                            onTap: () =>
                                _launchUrl('http://localhost:8080/q/health'),
                          ),
                        ],
                        onStart: () => notifier.startGollek(),
                        onStop: () => notifier.stopGollek(),
                        onRestart: () => notifier.restartGollek(),
                      ),
                    ),
                    const Gap(16),
                    Expanded(
                      child: _ServerCard(
                        type: ServerType.alhambra,
                        server: backendState.alhambra,
                        bootOrderLabel: 'BOOT STEP 2',
                        icon: Icons.hub_outlined,
                        primaryPortLabel: 'HTTP :8085 / gRPC :9000',
                        features: const [
                          'Autonomous Coder',
                          'Verification Ladder (L0-L5)',
                          'Muqabala LSP Kernel',
                          'Context Engine',
                        ],
                        quickLinks: [
                          _QuickLink(
                            label: 'Dev UI',
                            icon: Icons.developer_mode,
                            onTap: () =>
                                _launchUrl('http://localhost:8085/q/dev-ui'),
                          ),
                          _QuickLink(
                            label: 'OpenAPI',
                            icon: Icons.api_outlined,
                            onTap: () => _launchUrl(
                                'http://localhost:8085/q/swagger-ui'),
                          ),
                          _QuickLink(
                            label: 'Health',
                            icon: Icons.health_and_safety_outlined,
                            onTap: () =>
                                _launchUrl('http://localhost:8085/q/health'),
                          ),
                        ],
                        onStart: () => notifier.startAlhambra(),
                        onStop: () => notifier.stopAlhambra(),
                        onRestart: () => notifier.restartAlhambra(),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Log Viewer Section ─────────────────────────────────────────
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  decoration: BoxDecoration(
                    color: AppTheme.panelAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      // Log Filter Toolbar
                      _buildLogToolbar(
                        backendState,
                        notifier,
                        filteredLogs,
                      ),

                      const Divider(height: 1, color: AppTheme.border),

                      // Log Terminal Content
                      Expanded(
                        child: Container(
                          color: const Color(0xFF0D1117),
                          child: filteredLogs.isEmpty
                              ? Center(
                                  child: Text(
                                    _filterText.isEmpty
                                        ? 'No log messages received yet. Start a server to stream real-time logs.'
                                        : 'No logs match filter "$_filterText"',
                                    style: const TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 13,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                )
                              : SelectionArea(
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.all(12),
                                    itemCount: filteredLogs.length,
                                    itemBuilder: (context, index) {
                                      return _LogLineWidget(
                                        line: filteredLogs[index],
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // ── Update Manager View ────────────────────────────────────────
              Expanded(
                child: _buildUpdateManagerView(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: const BoxDecoration(
        color: AppTheme.panelAlt,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          _NavItemButton(
            icon: Icons.dashboard_outlined,
            label: 'Dual Substrates & Telemetry',
            isSelected: _activeTopNav == 0,
            onTap: () => setState(() => _activeTopNav = 0),
          ),
          const SizedBox(width: 8),
          _NavItemButton(
            icon: Icons.system_update_alt_rounded,
            label: 'Update Manager & Release Matrix',
            isSelected: _activeTopNav == 1,
            onTap: () => setState(() => _activeTopNav = 1),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const BackendOnboardingDialog(),
              );
            },
            icon: const Icon(Icons.build_circle_outlined, size: 14),
            label: const Text('Setup / Repair Wizard',
                style: TextStyle(fontSize: 11.5)),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.accent,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    BackendState backendState,
    BackendProcessNotifier notifier,
  ) {
    final anyRunning = backendState.alhambra.status == BackendStatus.running ||
        backendState.gollek.status == BackendStatus.running;
    final anyStarting = backendState.alhambra.status == BackendStatus.starting ||
        backendState.gollek.status == BackendStatus.starting;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.accent.withValues(alpha: 0.3),
              ),
            ),
            child:
                const Icon(Icons.dns_rounded, size: 20, color: AppTheme.accent),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Backend Infrastructure Supervisor',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(width: 8),
                    _PillBadge(label: 'Dual Substrate', isAccent: true),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  'Ordered Boot: [1] Gollek Inference (gRPC :9131 / :8080) -> [2] Andalus/Alhambra Agentic Platform (:8085)',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Master Controls
          FilledButton.icon(
            onPressed: anyStarting ? null : () => notifier.startAll(),
            icon: const Icon(Icons.play_arrow_rounded, size: 16),
            label: const Text('Start Backends (Ordered)'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF238636),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed:
                anyRunning || anyStarting ? () => notifier.stopAll() : null,
            icon: const Icon(Icons.stop_rounded, size: 16),
            label: const Text('Stop All'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade400,
              side: BorderSide(
                  color: (anyRunning || anyStarting)
                      ? Colors.red.shade400.withValues(alpha: 0.6)
                      : AppTheme.border),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Probe Ports & Refresh',
            icon: const Icon(Icons.refresh_rounded,
                size: 18, color: AppTheme.textSecondary),
            onPressed: () => notifier.probeServers(),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded,
                size: 20, color: AppTheme.textMuted),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateManagerView() {
    final updateAsync = ref.watch(updateManifestProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      child: updateAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
        error: (e, _) => Center(
          child: Text('Failed to check updates: $e',
              style: const TextStyle(color: Colors.red)),
        ),
        data: (manifest) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Component Version & Update Matrix',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => ref.refresh(updateManifestProvider),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Check for Updates'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.border),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _VersionCard(
                  info: manifest.gui, icon: Icons.desktop_windows_outlined),
              const SizedBox(height: 12),
              _VersionCard(info: manifest.gollek, icon: Icons.memory_outlined),
              const SizedBox(height: 12),
              _VersionCard(info: manifest.alhambra, icon: Icons.hub_outlined),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.panelAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: AppTheme.textMuted),
                    SizedBox(width: 8),
                    Text(
                      'All components are configured on the latest release channel (0.1.0-SNAPSHOT / local dev).',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLogToolbar(
    BackendState backendState,
    BackendProcessNotifier notifier,
    List<String> visibleLogs,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
      ),
      child: Row(
        children: [
          // Filter Tabs: All | Gollek | Alhambra | Alhambra UI
          _LogTabButton(
            label: 'All Logs (${backendState.logs.length})',
            isSelected: backendState.activeLogTab == 'all',
            onTap: () => notifier.setActiveLogTab('all'),
          ),
          const SizedBox(width: 6),
          _LogTabButton(
            label: 'Gollek (${backendState.gollek.logs.length})',
            isSelected: backendState.activeLogTab == 'gollek',
            onTap: () => notifier.setActiveLogTab('gollek'),
          ),
          const SizedBox(width: 6),
          _LogTabButton(
            label: 'Alhambra (${backendState.alhambra.logs.length})',
            isSelected: backendState.activeLogTab == 'alhambra',
            onTap: () => notifier.setActiveLogTab('alhambra'),
          ),
          const SizedBox(width: 6),
          _LogTabButton(
            label: 'Alhambra UI (${backendState.frontend.logs.length})',
            isSelected: backendState.activeLogTab == 'frontend',
            onTap: () => notifier.setActiveLogTab('frontend'),
          ),

          const Spacer(),

          // Search in logs
          SizedBox(
            width: 180,
            height: 28,
            child: TextField(
              controller: _searchController,
              style:
                  const TextStyle(fontSize: 11.5, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Filter logs...',
                hintStyle:
                    const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                prefixIcon: const Icon(Icons.search,
                    size: 14, color: AppTheme.textMuted),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 26, minHeight: 26),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Auto-scroll switch
          InkWell(
            onTap: () => setState(() => _autoScroll = !_autoScroll),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _autoScroll
                        ? Icons.check_box_outlined
                        : Icons.check_box_outline_blank,
                    size: 14,
                    color: _autoScroll ? AppTheme.accent : AppTheme.textMuted,
                  ),
                  const SizedBox(width: 4),
                  const Text('Autoscroll',
                      style: TextStyle(
                          fontSize: 11.5, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Select All / Copy Logs
          IconButton(
            tooltip: 'Select All & Copy Visible Logs',
            icon: const Icon(Icons.select_all_rounded,
                size: 16, color: AppTheme.textSecondary),
            onPressed: () {
              final text = visibleLogs.join('\n');
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '${visibleLogs.length} log lines selected & copied to clipboard'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Copy Visible Logs',
            icon: const Icon(Icons.copy_rounded,
                size: 14, color: AppTheme.textSecondary),
            onPressed: () {
              final text = visibleLogs.join('\n');
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '${visibleLogs.length} log lines copied to clipboard'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),

          // Clear logs
          IconButton(
            tooltip: 'Clear Logs',
            icon: const Icon(Icons.delete_outline_rounded,
                size: 14, color: AppTheme.textSecondary),
            onPressed: () => notifier.clearLogs(
              backendState.activeLogTab == 'alhambra'
                  ? ServerType.alhambra
                  : backendState.activeLogTab == 'gollek'
                      ? ServerType.gollek
                      : backendState.activeLogTab == 'frontend'
                          ? ServerType.frontend
                          : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Version Card Component ──────────────────────────────────────────────────

class _VersionCard extends StatelessWidget {
  final ComponentVersionInfo info;
  final IconData icon;

  const _VersionCard({required this.info, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.panelAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.componentName,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Installed: v${info.currentVersion} • Latest: v${info.latestVersion}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          if (info.hasUpdate) ...[
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.system_update_alt_rounded, size: 14),
              label: const Text('Update Now'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.black,
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 13, color: Colors.green),
                  SizedBox(width: 4),
                  Text('Up to Date',
                      style: TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Server Card Component ───────────────────────────────────────────────────

class _ServerCard extends StatelessWidget {
  final ServerType type;
  final SingleServerState server;
  final String bootOrderLabel;
  final IconData icon;
  final String primaryPortLabel;
  final List<String> features;
  final List<_QuickLink> quickLinks;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onRestart;

  const _ServerCard({
    required this.type,
    required this.server,
    required this.bootOrderLabel,
    required this.icon,
    required this.primaryPortLabel,
    required this.features,
    required this.quickLinks,
    required this.onStart,
    required this.onStop,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusLabel;
    switch (server.status) {
      case BackendStatus.running:
        statusColor = const Color(0xFF3FB950);
        statusLabel = 'ONLINE';
        break;
      case BackendStatus.starting:
        statusColor = const Color(0xFFD29922);
        statusLabel = 'STARTING...';
        break;
      case BackendStatus.error:
        statusColor = const Color(0xFFF85149);
        statusLabel = 'ERROR';
        break;
      case BackendStatus.stopped:
        statusColor = const Color(0xFF8B949E);
        statusLabel = 'STOPPED';
        break;
    }

    final isRunning = server.status == BackendStatus.running;
    final isStarting = server.status == BackendStatus.starting;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isRunning ? statusColor.withValues(alpha: 0.35) : AppTheme.border,
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Title + Status Pill + Boot Order Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(icon, size: 18, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          server.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _PillBadge(label: bootOrderLabel),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      server.description,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(label: statusLabel, color: statusColor),
            ],
          ),

          const SizedBox(height: 12),

          // Ports & PID metadata bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lan_outlined,
                    size: 13, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Text(
                  primaryPortLabel,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (server.pid != null) ...[
                  Text(
                    'PID: ${server.pid}',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                if (server.startedAt != null)
                  Text(
                    'Up: ${_formatDuration(server.uptime)}',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Features Chips Wrap
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: features.map((f) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.panelAlt,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '• $f',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10.5,
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // Quick Links + Actions Row
          Row(
            children: [
              // Quick Links (Swagger, Dev UI, Models)
              ...quickLinks.map((ql) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: OutlinedButton.icon(
                      onPressed: isRunning ? ql.onTap : null,
                      icon: Icon(ql.icon, size: 12),
                      label:
                          Text(ql.label, style: const TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(color: AppTheme.border),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  )),

              const Spacer(),

              // Start / Stop / Restart Button
              if (isRunning) ...[
                IconButton(
                  tooltip: 'Restart',
                  icon: const Icon(Icons.replay_rounded,
                      size: 16, color: AppTheme.textSecondary),
                  onPressed: onRestart,
                ),
                const SizedBox(width: 4),
                FilledButton.icon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop_rounded, size: 14),
                  label: const Text('Stop', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade900.withValues(alpha: 0.8),
                    foregroundColor: Colors.red.shade100,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ] else ...[
                FilledButton.icon(
                  onPressed: isStarting ? null : onStart,
                  icon: const Icon(Icons.play_arrow_rounded, size: 14),
                  label: Text(isStarting ? 'Starting...' : 'Start',
                      style: const TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '0s';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inSeconds}s';
  }
}

// ── Small UI Elements ───────────────────────────────────────────────────────

class _NavItemButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItemButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.panel : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? AppTheme.accent.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: isSelected ? AppTheme.accent : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  final String label;
  final bool isAccent;

  const _PillBadge({required this.label, this.isAccent = false});

  @override
  Widget build(BuildContext context) {
    final color = isAccent ? AppTheme.accent : AppTheme.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _QuickLink {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickLink({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

class _LogTabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LogTabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.panelAlt : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? AppTheme.accent.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _LogLineWidget extends StatelessWidget {
  final String line;

  const _LogLineWidget({required this.line});

  @override
  Widget build(BuildContext context) {
    Color textColor = const Color(0xFFC9D1D9);

    if (line.contains('ERROR') ||
        line.contains('Exception') ||
        line.contains('Failed') ||
        line.contains('❌')) {
      textColor = const Color(0xFFFFA198);
    } else if (line.contains('WARN') ||
        line.contains('WARNING') ||
        line.contains('⚠️')) {
      textColor = const Color(0xFFE3B341);
    } else if (line.contains('Listening on:') ||
        line.contains('started in') ||
        line.contains('SUCCESS') ||
        line.contains('🚀') ||
        line.contains('ONLINE') ||
        line.contains('✅')) {
      textColor = const Color(0xFF7EE787);
    } else if (line.startsWith('[Alhambra UI]') || line.contains('alhambra_gui')) {
      textColor = const Color(0xFF56D364);
    } else if (line.startsWith('[Alhambra]')) {
      textColor = const Color(0xFF79C0FF);
    } else if (line.startsWith('[Gollek]')) {
      textColor = const Color(0xFFD2A8FF);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Text(
        line,
        style: TextStyle(
          color: textColor,
          fontFamily: 'monospace',
          fontSize: 11.5,
          height: 1.35,
        ),
      ),
    );
  }
}
