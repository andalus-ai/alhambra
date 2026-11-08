import 'package:alhambra_core/alhambra_core.dart';
import '../review/review_decision.dart';
import '../task/intelligence_request.dart';
import '../task/intelligence_result.dart';

/// Top-level agent interface. High-level domains submit requests to an agent,
/// which coordinates planning, execution, and synthesis.
abstract interface class IntelligenceAgent {
  Future<IntelligenceResult> execute(IntelligenceRequest request);
}

/// Agent that supports pausing at review gates and resuming execution.
abstract interface class ResumableIntelligenceAgent implements IntelligenceAgent {
  Future<IntelligenceResult> resume(
    ExecutionId executionId,
    ReviewDecision decision,
  );
}
