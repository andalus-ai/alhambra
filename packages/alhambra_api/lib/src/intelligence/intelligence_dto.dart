import '../common/api_request.dart';

/// Request payload to start an intelligence execution.
final class StartIntelligenceRequest extends ApiRequest {
  final String workspaceId;
  final String objectiveType;
  final Map<String, Object?> parameters;
  final Map<String, Object?> context;

  const StartIntelligenceRequest({
    required this.workspaceId,
    required this.objectiveType,
    this.parameters = const {},
    this.context = const {},
    super.idempotencyKey,
  });
}

/// DTO representation of an intelligence execution.
final class IntelligenceExecutionDto {
  final String executionId;
  final String requestId;
  final String status;
  final String? runtimeExecutionId;
  final String? agentId;
  final String? workflowId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final Map<String, Object?> outputs;

  const IntelligenceExecutionDto({
    required this.executionId,
    required this.requestId,
    required this.status,
    this.runtimeExecutionId,
    this.agentId,
    this.workflowId,
    required this.startedAt,
    this.completedAt,
    this.outputs = const {},
  });

  @override
  String toString() =>
      'IntelligenceExecutionDto($executionId: $status, runtimeId: $runtimeExecutionId)';
}

/// Request payload to resume a paused intelligence execution.
final class ResumeIntelligenceRequest extends ApiRequest {
  final String decision; // 'approve' | 'reject' | 'requestChanges'
  final String? comment;

  const ResumeIntelligenceRequest({
    required this.decision,
    this.comment,
    super.idempotencyKey,
  });
}

/// Filter criteria for listing executions.
final class ExecutionListRequest {
  final String? workspaceId;
  final String? status;
  final int page;
  final int pageSize;

  const ExecutionListRequest({
    this.workspaceId,
    this.status,
    this.page = 0,
    this.pageSize = 20,
  });
}

/// DTO representation of a real-time execution event.
final class IntelligenceExecutionEventDto {
  final String executionId;
  final String eventId;
  final String type;
  final DateTime timestamp;
  final Map<String, Object?> data;

  const IntelligenceExecutionEventDto({
    required this.executionId,
    required this.eventId,
    required this.type,
    required this.timestamp,
    this.data = const {},
  });

  @override
  String toString() => 'IntelligenceExecutionEventDto($type for $executionId at $timestamp)';
}
