
/// A manifest file that contains information about an extension.
///
/// It is used by the extension loader to load an extension.
class ExtensionManifest {
  /// The unique identifier of the extension.
  final String id;

  /// The name of the extension.
  final String name;

  /// The version of the extension.
  final String version;

  /// The description of the extension.
  final String description;

  /// The author of the extension.
  final String? author;

  /// The capabilities of the extension.
  final List<String> capabilities;

  /// The dependencies of the extension.
  final List<String> dependencies;

  /// The main entry point of the extension.
  final String? main;

  const ExtensionManifest({
    required this.id,
    required this.name,
    required this.version,
    this.description = '',
    this.author,
    this.capabilities = const [],
    this.dependencies = const [],
    this.main,
  });

  factory ExtensionManifest.fromJson(Map<String, dynamic> json) {
    return ExtensionManifest(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      version: json['version'] as String? ?? '1.0.0',
      description: json['description'] as String? ?? '',
      author: json['author'] as String?,
      capabilities: (json['capabilities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      dependencies: (json['dependencies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      main: json['main'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'description': description,
        if (author != null) 'author': author,
        'capabilities': capabilities,
        'dependencies': dependencies,
        if (main != null) 'main': main,
      };
}
