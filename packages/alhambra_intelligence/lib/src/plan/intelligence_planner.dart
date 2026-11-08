import '../task/intelligence_request.dart';
import 'intelligence_plan.dart';
import 'intelligence_step.dart';

/// Contract for turning an [IntelligenceRequest] into an executable [IntelligencePlan]
/// without executing it.
abstract interface class IntelligencePlanner {
  Future<IntelligencePlan> plan(IntelligenceRequest request);
}

/// A simple rule-based planner for tests and generic default pipelines.
final class DefaultIntelligencePlanner implements IntelligencePlanner {
  const DefaultIntelligencePlanner();

  @override
  Future<IntelligencePlan> plan(IntelligenceRequest request) async {
    return IntelligencePlan(
      planId: 'plan-${request.requestId.value}',
      steps: [
        IntelligenceStep(
          id: 'step-data-acquire',
          type: 'acquire_data',
          parameters: {'subject': request.subject},
        ),
        IntelligenceStep(
          id: 'step-execute-core',
          type: request.objective.type,
          dependsOn: const ['step-data-acquire'],
          parameters: request.objective.parameters,
        ),
        IntelligenceStep(
          id: 'step-synthesize',
          type: 'synthesize_findings',
          dependsOn: const ['step-execute-core'],
        ),
      ],
    );
  }
}
