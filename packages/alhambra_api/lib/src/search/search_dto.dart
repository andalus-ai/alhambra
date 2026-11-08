import '../common/api_request.dart';

/// Request DTO for cross-resource platform search.
final class SearchRequest extends ApiRequest {
  final String query;
  final List<String> resourceTypes;
  final String? organizationId;
  final String? workspaceId;
  final int page;
  final int pageSize;

  const SearchRequest({
    required this.query,
    this.resourceTypes = const [],
    this.organizationId,
    this.workspaceId,
    this.page = 0,
    this.pageSize = 20,
    super.idempotencyKey,
  });
}

/// DTO representing an individual search match.
final class SearchResultDto {
  final String id;
  final String resourceType;
  final String title;
  final String? snippet;
  final double score;
  final Map<String, Object?> metadata;

  const SearchResultDto({
    required this.id,
    required this.resourceType,
    required this.title,
    this.snippet,
    this.score = 1.0,
    this.metadata = const {},
  });
}

/// Page of search results.
final class SearchResultPage {
  final List<SearchResultDto> items;
  final int page;
  final int pageSize;
  final int total;

  const SearchResultPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  bool get hasNextPage => (page + 1) * pageSize < total;
}
