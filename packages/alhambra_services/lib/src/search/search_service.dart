import 'package:alhambra_core/alhambra_core.dart';

/// Search scope — restricts which resources are included in results.
///
/// All constraints are additive (AND semantics).
final class SearchScope {
  final OrganizationId? organizationId;
  final String? workspaceId;
  final Set<String> resourceTypes;

  const SearchScope({
    this.organizationId,
    this.workspaceId,
    this.resourceTypes = const {},
  });
}

/// Generic search query. The platform does not know the meaning of [text] —
/// that interpretation belongs to the backend search engine.
final class SearchQuery {
  final String text;
  final SearchScope? scope;
  final int page;
  final int pageSize;

  const SearchQuery({
    required this.text,
    this.scope,
    this.page = 0,
    this.pageSize = 20,
  });
}

/// Generic search document for indexing platform resources.
final class SearchDocument {
  final String resourceType;
  final String resourceId;
  final String? organizationId;
  final String? workspaceId;
  final String title;
  final String? content;
  final Map<String, Object?> metadata;

  const SearchDocument({
    required this.resourceType,
    required this.resourceId,
    this.organizationId,
    this.workspaceId,
    required this.title,
    this.content,
    this.metadata = const {},
  });
}

/// A single resource match from a search query.
final class SearchResult {
  final String resourceType;
  final String resourceId;
  final String title;
  final String? description;
  final double? score;
  final Map<String, Object?> metadata;

  const SearchResult({
    required this.resourceType,
    required this.resourceId,
    required this.title,
    this.description,
    this.score,
    this.metadata = const {},
  });
}

/// Paginated search response.
final class SearchResponse {
  final List<SearchResult> results;
  final int total;

  const SearchResponse({
    required this.results,
    required this.total,
  });

  bool get hasResults => results.isNotEmpty;
}

/// Platform-wide search contract.
///
/// Authorization constraints are expressed via [SearchScope]. The backend
/// enforces them; the UI never hides unauthorized results after the fact.
abstract interface class SearchService {
  Future<SearchResponse> search(SearchQuery query);

  Future<void> index(SearchDocument document);

  Future<void> remove(String resourceType, String resourceId);
}

// ---------------------------------------------------------------------------
// In-memory implementation
// ---------------------------------------------------------------------------

/// In-memory [SearchService] for tests. Does simple substring matching on title and content.
final class InMemorySearchService implements SearchService {
  final List<SearchResult> _index;

  InMemorySearchService([List<SearchResult> initial = const []])
      : _index = List<SearchResult>.from(initial);

  @override
  Future<SearchResponse> search(SearchQuery query) async {
    final lower = query.text.toLowerCase();
    final filtered = _index.where((r) {
      final typeMatch = query.scope == null ||
          query.scope!.resourceTypes.isEmpty ||
          query.scope!.resourceTypes.contains(r.resourceType);
      final textMatch = r.title.toLowerCase().contains(lower) ||
          (r.description?.toLowerCase().contains(lower) ?? false);
      return typeMatch && textMatch;
    }).toList()
      ..sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));

    final start = query.page * query.pageSize;
    final paged = start < filtered.length
        ? filtered.sublist(
            start, (start + query.pageSize).clamp(0, filtered.length))
        : <SearchResult>[];

    return SearchResponse(results: paged, total: filtered.length);
  }

  @override
  Future<void> index(SearchDocument document) async {
    _index.removeWhere((r) =>
        r.resourceType == document.resourceType &&
        r.resourceId == document.resourceId);
    _index.add(SearchResult(
      resourceType: document.resourceType,
      resourceId: document.resourceId,
      title: document.title,
      description: document.content,
      metadata: document.metadata,
      score: 1.0,
    ));
  }

  @override
  Future<void> remove(String resourceType, String resourceId) async {
    _index.removeWhere((r) =>
        r.resourceType == resourceType && r.resourceId == resourceId);
  }
}
