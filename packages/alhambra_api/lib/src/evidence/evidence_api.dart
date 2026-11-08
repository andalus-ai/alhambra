import '../common/api_page.dart';
import '../common/api_response.dart';
import 'evidence_dto.dart';

/// Resource endpoint contract for retrieving and listing evidence.
abstract interface class EvidenceApi {
  Future<ApiResponse<EvidenceDto>> get(String evidenceId);

  Future<ApiResponse<ApiPage<EvidenceDto>>> list(
    EvidenceListRequest request,
  );
}
