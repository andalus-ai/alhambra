/// Filter/search specification for querying knowledge repositories.
final class KnowledgeQuery {
  final String text;
  final String? domain;
  final Set<String> tags;
  final int limit;

  const KnowledgeQuery({
    required this.text,
    this.domain,
    this.tags = const {},
    this.limit = 10,
  });

  @override
  String toString() => 'KnowledgeQuery("$text", domain: $domain, tags: $tags)';
}
