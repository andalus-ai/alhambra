import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../plugin/models/plugin.dart';
import '../models/marketplace.dart';

class PluginRepository {
  final Ref ref;
  List<Plugin> _pluginCache = [];
  List<Marketplace> _marketplaceCache = [];
  bool _initialized = false;

  PluginRepository(this.ref);

  Future<void> _initialize() async {
    if (_initialized) return;

    try {
      await _loadFromStorage();
      if (_pluginCache.isEmpty) {
        _pluginCache = _getDefaultPlugins();
        await _saveToStorage();
      }
      if (_marketplaceCache.isEmpty) {
        _marketplaceCache = _getDefaultMarketplaces();
        await _saveMarketplacesToStorage();
      }
    } catch (e) {
      _pluginCache = _getDefaultPlugins();
      _marketplaceCache = _getDefaultMarketplaces();
    }
    _initialized = true;
  }

  List<Plugin> _getDefaultPlugins() {
    return [
      Plugin(
        id: 'pdf-viewer',
        name: 'PDFViewer',
        author: 'Anthropic',
        lastUpdated: DateTime(2026, 7, 15),
        description:
            'View, annotate, and manage PDF documents with advanced features',
        version: '2.3.1',
        type: PluginType.official,
        capabilities: ['view', 'annotate', 'search', 'export'],
        downloads: 15234,
        rating: 4.8,
        tags: ['productivity', 'document'],
        homepage: 'https://anthropic.com/plugins/pdf-viewer',
      ),
      Plugin(
        id: 'reflect',
        name: 'Reflect',
        author: 'Anthropic',
        lastUpdated: DateTime(2026, 7, 15),
        description: 'Reflection and analysis tools for better decision making',
        version: '1.7.0',
        type: PluginType.official,
        capabilities: ['analysis', 'reflection', 'decision-support'],
        downloads: 8765,
        rating: 4.6,
        tags: ['productivity', 'analysis'],
        homepage: 'https://anthropic.com/plugins/reflect',
      ),
      Plugin(
        id: 'claude-code',
        name: 'Claude Code',
        author: 'Anthropic',
        lastUpdated: DateTime(2026, 7, 15),
        description: 'AI-powered code generation, analysis, and optimization',
        version: '3.1.2',
        type: PluginType.official,
        status: PluginStatus.installed,
        capabilities: [
          'code-generation',
          'analysis',
          'optimization',
          'debugging',
        ],
        downloads: 23456,
        rating: 4.9,
        tags: ['development', 'ai'],
        homepage: 'https://anthropic.com/plugins/claude-code',
      ),
      Plugin(
        id: 'time-focus',
        name: 'Time and Focus',
        author: 'Anthropic',
        lastUpdated: DateTime(2026, 7, 14),
        description: 'Time management and focus enhancement tools',
        version: '1.2.0',
        type: PluginType.official,
        capabilities: ['time-tracking', 'focus', 'productivity'],
        downloads: 5432,
        rating: 4.3,
        tags: ['productivity', 'time-management'],
        homepage: 'https://anthropic.com/plugins/time-focus',
      ),
      Plugin(
        id: 'extensions',
        name: 'Extensions',
        author: 'Anthropic',
        lastUpdated: DateTime(2026, 7, 13),
        description: 'Extend Claude\'s capabilities with custom extensions',
        version: '2.0.1',
        type: PluginType.official,
        capabilities: ['extension-management', 'customization'],
        downloads: 9876,
        rating: 4.5,
        tags: ['development', 'customization'],
        homepage: 'https://anthropic.com/plugins/extensions',
      ),
      Plugin(
        id: 'code-assistant',
        name: 'Code Assistant Pro',
        author: 'DevTools Inc',
        lastUpdated: DateTime(2026, 7, 10),
        description: 'Advanced code assistance with AI-powered suggestions',
        version: '3.0.0',
        type: PluginType.marketplace,
        marketplaceId: 'community-plugins',
        capabilities: ['code-completion', 'refactoring', 'testing'],
        downloads: 12345,
        rating: 4.7,
        tags: ['development', 'ai'],
        homepage: 'https://devtools.io/plugins/code-assistant',
      ),
    ];
  }

  List<Marketplace> _getDefaultMarketplaces() {
    return [
      Marketplace(
        id: 'anthropic-official',
        name: 'Anthropic Official',
        description: 'Curated marketplace of plugins built by Anthropic',
        source: MarketplaceSource.anthropic,
        url: 'https://marketplace.anthropic.com/official',
        iconUrl: 'https://anthropic.com/favicon.ico',
        categories: ['Official', 'Featured', 'Recommended'],
        pluginCount: 15,
        isEnabled: true,
        lastSynced: DateTime.now(),
      ),
      Marketplace(
        id: 'community-plugins',
        name: 'Community Marketplace',
        description: 'Community-driven plugins from verified developers',
        source: MarketplaceSource.github,
        url: 'https://github.com/anthropic/community-plugins',
        categories: ['Community', 'Open Source'],
        pluginCount: 42,
        isEnabled: true,
        lastSynced: DateTime.now().subtract(const Duration(hours: 12)),
      ),
    ];
  }

  Future<void> _loadFromStorage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final pluginFile = File('${directory.path}/plugins.json');
      final marketplaceFile = File('${directory.path}/marketplaces.json');

      if (await pluginFile.exists()) {
        final content = await pluginFile.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        _pluginCache = jsonList.map((json) => Plugin.fromJson(json)).toList();
      }

      if (await marketplaceFile.exists()) {
        final content = await marketplaceFile.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        _marketplaceCache =
            jsonList.map((json) => Marketplace.fromJson(json)).toList();
      }
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/plugins.json');
      final json = jsonEncode(_pluginCache.map((p) => p.toJson()).toList());
      await file.writeAsString(json);
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _saveMarketplacesToStorage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/marketplaces.json');
      final json = jsonEncode(
        _marketplaceCache.map((m) => m.toJson()).toList(),
      );
      await file.writeAsString(json);
    } catch (e) {
      // Silent fail
    }
  }

  Future<List<Plugin>> getPlugins() async {
    await _initialize();
    return _pluginCache;
  }

  Future<List<Marketplace>> getMarketplaces() async {
    await _initialize();
    return _marketplaceCache;
  }

  Future<void> addPlugin(Plugin plugin) async {
    _pluginCache = [..._pluginCache, plugin];
    await _saveToStorage();
  }

  Future<void> removePlugin(String id) async {
    _pluginCache = _pluginCache.where((p) => p.id != id).toList();
    await _saveToStorage();
  }

  Future<void> updatePlugin(Plugin plugin) async {
    final index = _pluginCache.indexWhere((p) => p.id == plugin.id);
    if (index != -1) {
      _pluginCache[index] = plugin;
      await _saveToStorage();
    }
  }

  Future<void> installPlugin(String id) async {
    final index = _pluginCache.indexWhere((p) => p.id == id);
    if (index != -1) {
      _pluginCache[index] = _pluginCache[index].copyWith(
        status: PluginStatus.installed,
        metadata: {
          ..._pluginCache[index].metadata,
          'installedAt': DateTime.now().toIso8601String(),
        },
      );
      await _saveToStorage();
    }
  }

  Future<void> addMarketplace(Marketplace marketplace) async {
    _marketplaceCache = [..._marketplaceCache, marketplace];
    await _saveMarketplacesToStorage();
  }

  Future<void> removeMarketplace(String id) async {
    _marketplaceCache = _marketplaceCache.where((m) => m.id != id).toList();
    await _saveMarketplacesToStorage();
  }

  Future<void> syncMarketplace(String marketplaceId) async {
    final index = _marketplaceCache.indexWhere((m) => m.id == marketplaceId);
    if (index != -1) {
      _marketplaceCache[index] = _marketplaceCache[index].copyWith(
        lastSynced: DateTime.now(),
      );
      await _saveMarketplacesToStorage();
    }
  }

  Future<List<Plugin>> getMarketplacePlugins(String marketplaceId) async {
    return _pluginCache.where((p) => p.marketplaceId == marketplaceId).toList();
  }

  Future<List<Plugin>> searchPlugins(String query) async {
    if (query.isEmpty) return _pluginCache;

    final lowerQuery = query.toLowerCase();
    return _pluginCache.where((plugin) {
      return plugin.name.toLowerCase().contains(lowerQuery) ||
          plugin.author.toLowerCase().contains(lowerQuery) ||
          (plugin.description?.toLowerCase().contains(lowerQuery) ?? false) ||
          plugin.capabilities.any(
            (c) => c.toLowerCase().contains(lowerQuery),
          ) ||
          plugin.tags.any((t) => t.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  Future<List<Plugin>> getPluginsByType(PluginType type) async {
    return _pluginCache.where((p) => p.type == type).toList();
  }

  Future<List<Plugin>> getInstalledPlugins() async {
    return _pluginCache.where((p) => p.isInstalled).toList();
  }

  Future<void> syncMarketplacePlugins(
    String marketplaceId,
    List<Plugin> plugins,
  ) async {
    // Remove existing plugins from this marketplace
    _pluginCache =
        _pluginCache.where((p) => p.marketplaceId != marketplaceId).toList();

    // Add new plugins
    _pluginCache = [..._pluginCache, ...plugins];
    await _saveToStorage();

    // Update marketplace sync time
    await syncMarketplace(marketplaceId);
  }
}
