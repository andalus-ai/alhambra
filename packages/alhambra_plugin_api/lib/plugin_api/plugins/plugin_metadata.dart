import '../capabilities/capabilities_models.dart';

/// Metadata for a plugin.
class PluginMetadata {
  /// The ID of the plugin.
  final String id;
  /// The name of the plugin.
  final String name;
  /// The version of the plugin.
  final String version;
  /// The description of the plugin.
  final String? description;
  /// The author of the plugin.
  final String? author;
  /// Declarative capabilities requested by the plugin.
  final List<CapabilityId> capabilities;

  /// Creates a new [PluginMetadata] instance.
  const PluginMetadata({
    required this.id,
    required this.name,
    required this.version,
    this.description,
    this.author,
    this.capabilities = const [],
  });
}
