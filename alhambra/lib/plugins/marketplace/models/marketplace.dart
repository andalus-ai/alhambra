enum MarketplaceSource { anthropic, github, git, custom }

class Marketplace {
  final String id;
  final String name;
  final String description;
  final MarketplaceSource source;
  final String url;
  final String? iconUrl;
  final List<String> categories;
  final int pluginCount;
  final bool isEnabled;
  final DateTime lastSynced;
  final Map<String, dynamic> config;

  Marketplace({
    required this.id,
    required this.name,
    required this.description,
    required this.source,
    required this.url,
    this.iconUrl,
    this.categories = const [],
    this.pluginCount = 0,
    this.isEnabled = true,
    required this.lastSynced,
    this.config = const {},
  });

  Marketplace copyWith({
    String? id,
    String? name,
    String? description,
    MarketplaceSource? source,
    String? url,
    String? iconUrl,
    List<String>? categories,
    int? pluginCount,
    bool? isEnabled,
    DateTime? lastSynced,
    Map<String, dynamic>? config,
  }) =>
      Marketplace(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        source: source ?? this.source,
        url: url ?? this.url,
        iconUrl: iconUrl ?? this.iconUrl,
        categories: categories ?? this.categories,
        pluginCount: pluginCount ?? this.pluginCount,
        isEnabled: isEnabled ?? this.isEnabled,
        lastSynced: lastSynced ?? this.lastSynced,
        config: config ?? this.config,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'source': source.toString(),
        'url': url,
        'iconUrl': iconUrl,
        'categories': categories,
        'pluginCount': pluginCount,
        'isEnabled': isEnabled,
        'lastSynced': lastSynced.toIso8601String(),
        'config': config,
      };

  factory Marketplace.fromJson(Map<String, dynamic> json) => Marketplace(
        id: json['id'],
        name: json['name'],
        description: json['description'],
        source: MarketplaceSource.values.firstWhere(
          (e) => e.toString() == json['source'],
          orElse: () => MarketplaceSource.custom,
        ),
        url: json['url'],
        iconUrl: json['iconUrl'],
        categories: List<String>.from(json['categories'] ?? []),
        pluginCount: json['pluginCount'] ?? 0,
        isEnabled: json['isEnabled'] ?? true,
        lastSynced: DateTime.parse(json['lastSynced']),
        config: json['config'] ?? {},
      );
}
