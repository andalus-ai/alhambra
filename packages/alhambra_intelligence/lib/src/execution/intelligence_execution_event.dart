import 'package:alhambra_core/alhambra_core.dart';
import '../artifact/intelligence_artifact.dart';
import '../evidence/evidence.dart';
import '../review/review_request.dart';
import 'intelligence_execution_status.dart';

/// Sealed hierarchy of lifecycle events emitted during intelligence execution.
sealed class IntelligenceExecutionEvent {
  final ExecutionId executionId;
  final DateTime timestamp;

  const IntelligenceExecutionEvent({
    required this.executionId,
    required this.timestamp,
  });
}

/// Emitted when execution changes status.
final class ExecutionStatusChanged extends IntelligenceExecutionEvent {
  final IntelligenceExecutionStatus status;

  const ExecutionStatusChanged({
    required super.executionId,
    required super.timestamp,
    required this.status,
  });
}

/// Emitted when a specific step starts.
final class StepStarted extends IntelligenceExecutionEvent {
  final String stepId;
  final String stepType;

  const StepStarted({
    required super.executionId,
    required super.timestamp,
    required this.stepId,
    required this.stepType,
  });
}

/// Emitted when a step completes.
final class StepCompleted extends IntelligenceExecutionEvent {
  final String stepId;
  final Map<String, Object?> outputs;

  const StepCompleted({
    required super.executionId,
    required super.timestamp,
    required this.stepId,
    this.outputs = const {},
  });
}

/// Emitted when human-in-the-loop review is requested.
final class ReviewRequestedEvent extends IntelligenceExecutionEvent {
  final ReviewRequest request;

  const ReviewRequestedEvent({
    required super.executionId,
    required super.timestamp,
    required this.request,
  });
}

/// Emitted when an artifact is produced.
final class ArtifactProduced extends IntelligenceExecutionEvent {
  final IntelligenceArtifact artifact;

  const ArtifactProduced({
    required super.executionId,
    required super.timestamp,
    required this.artifact,
  });
}

/// Emitted when evidence is added.
final class EvidenceAdded extends IntelligenceExecutionEvent {
  final Evidence evidence;

  const EvidenceAdded({
    required super.executionId,
    required super.timestamp,
    required this.evidence,
  });
}
