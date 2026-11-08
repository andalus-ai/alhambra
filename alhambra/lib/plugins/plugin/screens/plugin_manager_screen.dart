// plugin_manager_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/screens/settings_dialog.dart';
import '../../marketplace/providers/marketplace_provider.dart';
import '../../marketplace/widgets/add_marketplace_dialog.dart';
import '../models/plugin.dart';
import '../widgets/plugin_bottom_nav.dart';
import '../widgets/plugin_detail_dialog.dart';
import '../widgets/plugin_header.dart';
import '../widgets/plugin_list.dart';
import '../widgets/plugin_option_bottom.dart';
import '../widgets/plugin_search_bar.dart';
import '../widgets/plugin_section_title.dart';

class PluginManagerScreen extends ConsumerStatefulWidget {
  const PluginManagerScreen({super.key});

  @override
  ConsumerState<PluginManagerScreen> createState() =>
      _PluginManagerScreenState();
}

class _PluginManagerScreenState extends ConsumerState<PluginManagerScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pluginsAsync = ref.watch(filteredPluginsProvider);
    final marketplacesAsync = ref.watch(marketplaceListProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            PluginHeader(
              marketplacesAsync: marketplacesAsync,
              onAddMarketplace: () => _showAddMarketplaceDialog(context),
              onSettings: () => _showSettingsDialog(context),
            ),
            PluginSearchBar(
              query: query,
              onSearchChanged: (value) {
                ref.read(searchQueryProvider.notifier).state = value;
              },
              onClearSearch: () {
                ref.read(searchQueryProvider.notifier).state = '';
              },
            ),
            PluginSectionTitle(
              pluginsAsync: pluginsAsync,
              marketplacesAsync: marketplacesAsync,
            ),
            Expanded(
              child: PluginList(
                scrollController: _scrollController,
                pluginsAsync: pluginsAsync,
                marketplacesAsync: marketplacesAsync,
                onInstall: (plugin) => _installPlugin(context, plugin),
                onUninstall: (plugin) => _uninstallPlugin(context, plugin),
                onDelete: (plugin) => _deletePlugin(context, plugin),
                onShowOptions: _showPluginOptions,
                onShowDetails: _showPluginDetails,
              ),
            ),
            PluginBottomNav(
              onTabSelected: (index) {
                ref.read(selectedMarketplaceIdProvider.notifier).state = null;
              },
            ),
          ],
        ),
      ),
    );
  }

  // Dialog Methods
  void _showAddMarketplaceDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AddMarketplaceDialog(),
    );
  }

  void _showPluginOptions(BuildContext context, Plugin plugin) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[850]
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => PluginOptionsBottomSheet(
        plugin: plugin,
        onInstall: () => _installPlugin(context, plugin),
        onUninstall: () => _uninstallPlugin(context, plugin),
        onDelete: () => _deletePlugin(context, plugin),
        onDetails: () => _showPluginDetails(context, plugin),
        onCheckUpdates: () => _checkForUpdates(context, plugin),
        onOpenHomepage: _openHomepage,
        onShare: _sharePlugin,
      ),
    );
  }

  void _showPluginDetails(BuildContext context, Plugin plugin) {
    showDialog(
      context: context,
      builder: (context) => PluginDetailsDialog(
        plugin: plugin,
        onInstall: () => _installPlugin(context, plugin),
        onUninstall: () => _uninstallPlugin(context, plugin),
        onDelete: () => _deletePlugin(context, plugin),
        onOpenHomepage: _openHomepage,
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const SettingsDialog(),
    );
  }

  // Action Methods
  Future<void> _installPlugin(BuildContext context, Plugin plugin) async {
    // Implementation...
  }

  Future<void> _uninstallPlugin(BuildContext context, Plugin plugin) async {
    // Implementation...
  }

  Future<void> _deletePlugin(BuildContext context, Plugin plugin) async {
    // Implementation...
  }

  Future<void> _checkForUpdates(BuildContext context, Plugin plugin) async {
    // Implementation...
  }

  Future<void> _openHomepage(String url) async {
    // Implementation...
  }

  Future<void> _sharePlugin(Plugin plugin) async {
    // Implementation...
  }
}
