import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../plugin/models/plugin.dart';
import '../models/marketplace.dart';
import 'plugin_repository.dart';

class PluginService {
  final Ref ref;
  final PluginRepository _repository;

  PluginService(this.ref) : _repository = PluginRepository(ref);

  Future<List<Plugin>> fetchMarketplacePlugins(String marketplaceId) async {
    try {
      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 800));

      // In production, fetch from actual API
      /* final marketplace = (await _repository.getMarketplaces()).firstWhere(
        (m) => m.id == marketplaceId,
      ); */

      // Simulate fetching plugins from marketplace URL
      // final response = await http.get(Uri.parse(marketplace.url));
      // final List<dynamic> data = jsonDecode(response.body);

      return [
        Plugin(
          id: 'ai-writer',
          name: 'AI Writer Assistant',
          author: 'ContentAI',
          lastUpdated: DateTime(2026, 7, 12),
          description: 'AI-powered writing assistant for better content',
          version: '2.1.0',
          type: PluginType.marketplace,
          marketplaceId: marketplaceId,
          capabilities: ['writing', 'editing', 'grammar'],
          downloads: 8765,
          rating: 4.6,
          tags: ['writing', 'ai'],
        ),
        Plugin(
          id: 'data-viz',
          name: 'Data Visualizer',
          author: 'DataLabs',
          lastUpdated: DateTime(2026, 7, 11),
          description: 'Create beautiful data visualizations and charts',
          version: '1.5.2',
          type: PluginType.marketplace,
          marketplaceId: marketplaceId,
          capabilities: ['visualization', 'charts', 'data-analysis'],
          downloads: 5432,
          rating: 4.4,
          tags: ['data', 'visualization'],
        ),
      ];
    } catch (e) {
      throw Exception('Failed to fetch marketplace plugins: $e');
    }
  }

  Future<void> syncRepositoryMarketplace(String url, String name) async {
    try {
      // Validate URL
      final uri = Uri.parse(url);
      if (!uri.isAbsolute) {
        throw Exception('Invalid repository URL');
      }

      // In production, fetch from repository
      // final response = await http.get(uri);
      // final manifest = jsonDecode(response.body);

      final newMarketplace = Marketplace(
        id: 'repo-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        description: 'Synced from repository: $url',
        source: MarketplaceSource.git,
        url: url,
        lastSynced: DateTime.now(),
        pluginCount: 0,
        categories: ['Repository', 'Synced'],
      );

      await _repository.addMarketplace(newMarketplace);

      // Fetch and add plugins from repository
      final plugins = await fetchMarketplacePlugins(newMarketplace.id);
      await _repository.syncMarketplacePlugins(newMarketplace.id, plugins);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> installPluginFromSource(String pluginId) async {
    try {
      final plugin = (await _repository.getPlugins()).firstWhere(
        (p) => p.id == pluginId,
      );

      // Check compatibility
      await _checkCompatibility(plugin);

      // Install
      await _repository.installPlugin(pluginId);

      if (plugin.requiresRestart) {
        await _repository.updatePlugin(
          plugin.copyWith(
            status: PluginStatus.pendingRestart,
            metadata: {...plugin.metadata, 'pendingRestart': true},
          ),
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _checkCompatibility(Plugin plugin) async {
    // Check platform
    final platform = Platform.operatingSystem;
    final supportedPlatforms = plugin.metadata['platforms'] ?? ['all'];

    if (!supportedPlatforms.contains(platform) &&
        !supportedPlatforms.contains('all')) {
      throw Exception('Plugin not supported on $platform');
    }

    // Check version
    final minVersion = plugin.metadata['minVersion'] ?? '1.0.0';
    const currentVersion = '1.0.0';

    if (!_isVersionCompatible(currentVersion, minVersion)) {
      throw Exception('Plugin requires version $minVersion or higher');
    }
  }

  bool _isVersionCompatible(String current, String required) {
    final currentParts = current.split('.').map(int.parse).toList();
    final requiredParts = required.split('.').map(int.parse).toList();

    for (int i = 0; i < requiredParts.length; i++) {
      if (currentParts[i] < requiredParts[i]) return false;
    }
    return true;
  }

  Future<void> uninstallPlugin(String pluginId) async {
    final plugin = (await _repository.getPlugins()).firstWhere(
      (p) => p.id == pluginId,
    );

    if (plugin.isUploaded || plugin.isFromRepository) {
      await _repository.removePlugin(pluginId);
    } else {
      await _repository.updatePlugin(
        plugin.copyWith(
          status: PluginStatus.notInstalled,
          metadata: {
            ...plugin.metadata,
            'uninstalledAt': DateTime.now().toIso8601String(),
          },
        ),
      );
    }
  }

  Future<List<Plugin>> searchPlugins(String query) async {
    return await _repository.searchPlugins(query);
  }

  Future<List<Marketplace>> getMarketplaces() async {
    return await _repository.getMarketplaces();
  }
}
