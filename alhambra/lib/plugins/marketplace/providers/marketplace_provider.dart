// ============ Providers ============
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../plugin/models/plugin.dart';
import '../models/marketplace.dart';
import '../services/plugin_repository.dart';
import '../services/plugin_service.dart';

final pluginRepositoryProvider = Provider<PluginRepository>((ref) {
  return PluginRepository(ref);
});

final pluginServiceProvider = Provider<PluginService>((ref) {
  return PluginService(ref);
});

final pluginListProvider = FutureProvider<List<Plugin>>((ref) async {
  final repository = ref.watch(pluginRepositoryProvider);
  return await repository.getPlugins();
});

final marketplaceListProvider = FutureProvider<List<Marketplace>>((ref) async {
  final repository = ref.watch(pluginRepositoryProvider);
  return await repository.getMarketplaces();
});

final installedPluginsProvider = FutureProvider<List<Plugin>>((ref) async {
  final repository = ref.watch(pluginRepositoryProvider);
  return await repository.getInstalledPlugins();
});

final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedMarketplaceIdProvider = StateProvider<String?>((ref) => null);

final filteredPluginsProvider = FutureProvider<List<Plugin>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final service = ref.watch(pluginServiceProvider);

  if (query.isEmpty) {
    final repository = ref.watch(pluginRepositoryProvider);
    return await repository.getPlugins();
  }

  return await service.searchPlugins(query);
});

final marketplacePluginsProvider = FutureProvider.family<List<Plugin>, String>((
  ref,
  marketplaceId,
) async {
  final repository = ref.watch(pluginRepositoryProvider);
  return await repository.getMarketplacePlugins(marketplaceId);
});

final pluginDetailProvider = FutureProvider.family<Plugin?, String>((
  ref,
  id,
) async {
  final plugins = await ref.watch(pluginListProvider.future);
  try {
    return plugins.firstWhere((p) => p.id == id);
  } catch (e) {
    return null;
  }
});

final syncInProgressProvider = StateProvider<Set<String>>((ref) => {});
final isInstallingProvider = StateProvider<Set<String>>((ref) => {});
