import '../common/api_response.dart';
import 'search_dto.dart';

/// API contract for search operations across Alhambra resources.
abstract interface class SearchApi {
  /// Executes a unified search across registered platform resources.
  Future<ApiResponse<SearchResultPage>> search(
    SearchRequest request,
  );
}
