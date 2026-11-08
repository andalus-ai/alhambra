class SkillEntity {
  final String id;
  final String name;
  final String description;
  final String? category;
  final String? reasoningMode;
  final bool mutatesWorkspace;
  final List<String> allowedTools;
  final String? sourcePath;
  final bool inTrash;
  final String? instructions;
  final String? rawMarkdown;

  SkillEntity({
    required this.id,
    required this.name,
    required this.description,
    this.category,
    this.reasoningMode,
    this.mutatesWorkspace = false,
    this.allowedTools = const [],
    this.sourcePath,
    this.inTrash = false,
    this.instructions,
    this.rawMarkdown,
  });

  factory SkillEntity.fromJson(Map<String, dynamic> json) {
    // Check if it's wrapped in a SkillDetailDto
    final summary =
        json['summary'] is Map<String, dynamic> ? json['summary'] : json;

    return SkillEntity(
      id: summary['id'] ?? json['id'] ?? '',
      name: summary['name'] ?? json['name'] ?? summary['id'] ?? 'Unknown Skill',
      description: summary['description'] ?? json['description'] ?? '',
      category: summary['category'] ?? json['category'],
      reasoningMode: summary['reasoningMode'] ?? json['reasoningMode'],
      mutatesWorkspace: summary['mutatesWorkspace'] == true ||
          json['mutatesWorkspace'] == true,
      allowedTools:
          ((summary['allowedTools'] ?? json['allowedTools']) as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
      sourcePath: summary['sourcePath'] ?? json['sourcePath'],
      inTrash: summary['inTrash'] == true || json['inTrash'] == true,
      instructions: json['instructions'] as String?,
      rawMarkdown: json['rawMarkdown'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category ?? 'coding',
      'reasoningMode': reasoningMode ?? 'standard',
      'mutatesWorkspace': mutatesWorkspace,
      'allowedTools': allowedTools,
      'instructions': instructions ?? '',
      'references': <String, String>{},
      'scripts': <String, String>{},
    };
  }

  SkillEntity copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    String? reasoningMode,
    bool? mutatesWorkspace,
    List<String>? allowedTools,
    String? sourcePath,
    bool? inTrash,
    String? instructions,
    String? rawMarkdown,
  }) {
    return SkillEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      reasoningMode: reasoningMode ?? this.reasoningMode,
      mutatesWorkspace: mutatesWorkspace ?? this.mutatesWorkspace,
      allowedTools: allowedTools ?? this.allowedTools,
      sourcePath: sourcePath ?? this.sourcePath,
      inTrash: inTrash ?? this.inTrash,
      instructions: instructions ?? this.instructions,
      rawMarkdown: rawMarkdown ?? this.rawMarkdown,
    );
  }
}
