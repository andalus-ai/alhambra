import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:test/test.dart';

void main() {
  test('keeps unsupported measurements distinct from zero', () {
    final snapshot = CompositionLifecycleStorageHealth(
      state: CompositionLifecycleStorageHealthState.unknown,
      checkedAt: DateTime.utc(2026, 10, 1),
    );

    expect(snapshot.recordCount, isNull);
    expect(snapshot.primaryStorageBytes, isNull);
    expect(snapshot.auxiliaryStorageBytes, isNull);
    expect(snapshot.pendingWrites, isNull);
  });

  test('copies and freezes backend metrics', () {
    final metrics = <String, Object?>{'adapter': 'test'};
    final snapshot = CompositionLifecycleStorageHealth(
      state: CompositionLifecycleStorageHealthState.healthy,
      checkedAt: DateTime.utc(2026, 10, 1),
      metrics: metrics,
    );
    metrics['adapter'] = 'mutated';

    expect(snapshot.metrics['adapter'], 'test');
    expect(
      () => snapshot.metrics['new'] = true,
      throwsUnsupportedError,
    );
  });

  test('rejects negative measurements', () {
    expect(
      () => CompositionLifecycleStorageHealth(
        state: CompositionLifecycleStorageHealthState.healthy,
        checkedAt: DateTime.utc(2026, 10, 1),
        recordCount: -1,
      ),
      throwsArgumentError,
    );
  });
}
