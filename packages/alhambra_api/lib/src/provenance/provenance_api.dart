import '../common/api_response.dart';
import 'provenance_dto.dart';

/// API contract for querying provenance graphs.
abstract interface class ProvenanceApi {
  /// Retrieves the provenance graph for a specific artifact.
  Future<ApiResponse<ProvenanceGraphDto>> getForArtifact(
    String artifactId,
  );

  /// Retrieves the provenance graph for a specific intelligence execution.
  Future<ApiResponse<ProvenanceGraphDto>> getForExecution(
    String executionId,
  );
}
