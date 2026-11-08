import '../common/api_page.dart';
import '../common/api_response.dart';
import 'artifact_dto.dart';

/// Resource endpoint contract for retrieving and querying artifacts.
abstract interface class ArtifactApi {
  Future<ApiResponse<IntelligenceArtifactDto>> get(String artifactId);

  Future<ApiResponse<ApiPage<IntelligenceArtifactDto>>> list(
    ArtifactListRequest request,
  );
}
