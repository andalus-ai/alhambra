import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

void main() {
  const codec = CompositionLifecycleEventJsonCodec();

  test('round-trips every lifecycle event field', () {
    final event = CompositionLifecycleEvent(
      correlationId: 'corr-42',
      operation: CompositionLifecycleOperation.compensate,
      status: CompositionLifecycleStatus.failed,
      timestamp: DateTime.utc(2026, 11, 11, 10, 20, 30, 123),
      nodeIds: const ['command:save', 'view:editor'],
      ownerIds: const ['editor-plugin'],
      duration: const Duration(microseconds: 987654),
      errorType: 'StateError',
      errorMessage: 'activation failed',
    );

    final decoded = codec.decode(codec.encode(event));

    expect(decoded.correlationId, event.correlationId);
    expect(decoded.operation, event.operation);
    expect(decoded.status, event.status);
    expect(decoded.timestamp, event.timestamp);
    expect(decoded.nodeIds, event.nodeIds);
    expect(decoded.ownerIds, event.ownerIds);
    expect(decoded.duration, event.duration);
    expect(decoded.errorType, event.errorType);
    expect(decoded.errorMessage, event.errorMessage);
    expect(() => decoded.nodeIds.add('extra'), throwsUnsupportedError);
  });

  test('round-trips events with optional fields omitted', () {
    final event = CompositionLifecycleEvent(
      correlationId: 'corr-optional',
      operation: CompositionLifecycleOperation.prepare,
      status: CompositionLifecycleStatus.started,
      timestamp: DateTime.utc(2026, 1, 1),
      nodeIds: const [],
      ownerIds: const [],
    );

    final decoded = codec.decode(codec.encode(event));

    expect(decoded.duration, isNull);
    expect(decoded.errorType, isNull);
    expect(decoded.errorMessage, isNull);
  });

  test('rejects unsupported schema versions', () {
    expect(
      () => codec.decode('{"schemaVersion":99}'),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects invalid enum values and malformed lists', () {
    final valid = codec.encode(_event());
    final invalidOperation = valid.replaceFirst('"prepare"', '"unknown"');
    expect(
      () => codec.decode(invalidOperation),
      throwsA(isA<FormatException>()),
    );

    final invalidIds = valid.replaceFirst('"nodeIds":[]', '"nodeIds":[1]');
    expect(
      () => codec.decode(invalidIds),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects invalid duration values', () {
    final valid = codec.encode(_event());
    final invalid = valid.replaceFirst(
      '"schemaVersion":1',
      '"schemaVersion":1,"durationMicros":-1',
    );
    expect(
      () => codec.decode(invalid),
      throwsA(isA<FormatException>()),
    );
  });
}

CompositionLifecycleEvent _event() => CompositionLifecycleEvent(
      correlationId: 'codec-test',
      operation: CompositionLifecycleOperation.prepare,
      status: CompositionLifecycleStatus.succeeded,
      timestamp: DateTime.utc(2026, 1, 1),
      nodeIds: const [],
      ownerIds: const [],
    );
