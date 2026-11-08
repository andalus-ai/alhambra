enum PluginType { official, marketplace, uploaded, repository }

enum PluginStatus { installed, notInstalled, updating, error, pendingRestart }

class Plugin {
  final String id;
  final String name;
  final String author;
  final DateTime lastUpdated;
  final String? description;
  final String version;
  final PluginType type;
  final PluginStatus status;
  final String? homepage;
  final String? iconPath;
  final Map<String, dynamic> metadata;
  final List<String> capabilities;
  final bool requiresRestart;
  final String? repositoryUrl;
  final String? marketplaceId;
  final int downloads;
  final double rating;
  final List<String> screenshots;
  final List<String> tags;

  Plugin({
    required this.id,
    required this.name,
    required this.author,
    required this.lastUpdated,
    this.description,
    this.version = '1.0.0',
    this.type = PluginType.official,
    this.status = PluginStatus.notInstalled,
    this.homepage,
    this.iconPath,
    this.metadata = const {},
    this.capabilities = const [],
    this.requiresRestart = false,
    this.repositoryUrl,
    this.marketplaceId,
    this.downloads = 0,
    this.rating = 0.0,
    this.screenshots = const [],
    this.tags = const [],
  });

  Plugin copyWith({
    String? id,
    String? name,
    String? author,
    DateTime? lastUpdated,
    String? description,
    String? version,
    PluginType? type,
    PluginStatus? status,
    String? homepage,
    String? iconPath,
    Map<String, dynamic>? metadata,
    List<String>? capabilities,
    bool? requiresRestart,
    String? repositoryUrl,
    String? marketplaceId,
    int? downloads,
    double? rating,
    List<String>? screenshots,
    List<String>? tags,
  }) {
    return Plugin(
      id: id ?? this.id,
      name: name ?? this.name,
      author: author ?? this.author,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      description: description ?? this.description,
      version: version ?? this.version,
      type: type ?? this.type,
      status: status ?? this.status,
      homepage: homepage ?? this.homepage,
      iconPath: iconPath ?? this.iconPath,
      metadata: metadata ?? this.metadata,
      capabilities: capabilities ?? this.capabilities,
      requiresRestart: requiresRestart ?? this.requiresRestart,
      repositoryUrl: repositoryUrl ?? this.repositoryUrl,
      marketplaceId: marketplaceId ?? this.marketplaceId,
      downloads: downloads ?? this.downloads,
      rating: rating ?? this.rating,
      screenshots: screenshots ?? this.screenshots,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'author': author,
        'lastUpdated': lastUpdated.toIso8601String(),
        'description': description,
        'version': version,
        'type': type.toString(),
        'status': status.toString(),
        'homepage': homepage,
        'iconPath': iconPath,
        'metadata': metadata,
        'capabilities': capabilities,
        'requiresRestart': requiresRestart,
        'repositoryUrl': repositoryUrl,
        'marketplaceId': marketplaceId,
        'downloads': downloads,
        'rating': rating,
        'screenshots': screenshots,
        'tags': tags,
      };

  factory Plugin.fromJson(Map<String, dynamic> json) => Plugin(
        id: json['id'],
        name: json['name'],
        author: json['author'],
        lastUpdated: DateTime.parse(json['lastUpdated']),
        description: json['description'],
        version: json['version'] ?? '1.0.0',
        type: PluginType.values.firstWhere(
          (e) => e.toString() == json['type'],
          orElse: () => PluginType.official,
        ),
        status: PluginStatus.values.firstWhere(
          (e) => e.toString() == json['status'],
          orElse: () => PluginStatus.notInstalled,
        ),
        homepage: json['homepage'],
        iconPath: json['iconPath'],
        metadata: json['metadata'] ?? {},
        capabilities: List<String>.from(json['capabilities'] ?? []),
        requiresRestart: json['requiresRestart'] ?? false,
        repositoryUrl: json['repositoryUrl'],
        marketplaceId: json['marketplaceId'],
        downloads: json['downloads'] ?? 0,
        rating: (json['rating'] ?? 0.0).toDouble(),
        screenshots: List<String>.from(json['screenshots'] ?? []),
        tags: List<String>.from(json['tags'] ?? []),
      );

  bool get isInstalled =>
      status == PluginStatus.installed || status == PluginStatus.pendingRestart;
  bool get isUploaded => type == PluginType.uploaded;
  bool get isOfficial => type == PluginType.official;
  bool get isMarketplace => type == PluginType.marketplace;
  bool get isFromRepository => type == PluginType.repository;

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(lastUpdated);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String get formattedDownloads {
    if (downloads >= 1000000) {
      return '${(downloads / 1000000).toStringAsFixed(1)}M';
    } else if (downloads >= 1000) {
      return '${(downloads / 1000).toStringAsFixed(1)}K';
    }
    return downloads.toString();
  }
}
