import '../common/api_page.dart';
import '../common/api_response.dart';
import 'intelligence_dto.dart';

/// Resource endpoint contract for intelligence executions, lifecycle controls, and streaming.
abstract interface class IntelligenceApi {
  Future<ApiResponse<IntelligenceExecutionDto>> start(
    StartIntelligenceRequest request,
  );

  Future<ApiResponse<IntelligenceExecutionDto>> getExecution(
    String executionId,
  );

  Future<ApiResponse<ApiPage<IntelligenceExecutionDto>>> listExecutions(
    ExecutionListRequest request,
  );

  Future<ApiResponse<IntelligenceExecutionDto>> resume(
    String executionId,
    ResumeIntelligenceRequest request,
  );

  Future<ApiResponse<void>> cancel(String executionId);
}
