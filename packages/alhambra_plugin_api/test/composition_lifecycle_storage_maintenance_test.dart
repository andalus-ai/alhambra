import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:test/test.dart';

void main() {
  test('requires at least one maintenance action', () {
    expect(
      () => CompositionLifecycleStorageMaintenanceRequest(),
      throwsArgumentError,
    );
  });

  test('rejects invalid retention limits', () {
    expect(
      () => CompositionLifecycleStorageMaintenanceRequest(maxEvents: 0),
      throwsArgumentError,
    );
  });

  test('keeps maintenance result collections immutable', () {
    final warnings = <String>['checkpoint unavailable'];
    final metrics = <String, Object?>{'adapter': 'test'};
    final result = CompositionLifecycleStorageMaintenanceResult(
      startedAt: DateTime.utc(2026, 1, 1),
      completedAt: DateTime.utc(2026, 1, 1, 0, 0, 1),
      checkpointRequested: true,
      warnings: warnings,
      metrics: metrics,
    );
    warnings.add('mutated');
    metrics['adapter'] = 'mutated';

    expect(result.warnings, ['checkpoint unavailable']);
    expect(result.metrics['adapter'], 'test');
    expect(result.partial, isTrue);
    expect(() => result.warnings.add('x'), throwsUnsupportedError);
  });
}
