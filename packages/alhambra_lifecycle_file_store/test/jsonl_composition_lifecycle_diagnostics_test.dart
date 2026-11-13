import 'dart:io';

import 'package:alhambra_lifecycle_file_store/alhambra_lifecycle_file_store.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('alhambra-diagnostics-');
    file = File('${directory.path}/lifecycle/events.jsonl');
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('merges durable and live events without double counting', () async {
    final host = JsonlCompositionLifecycleRuntime(file: file);
    final transaction = host.runtime.beginTransaction(
      lifecycle: _Lifecycle(),
      correlationId: 'install-search',
    )..stage(ServiceNode(serviceId: 'index', ownerId: 'search-plugin'));

    expect(transaction.commit(), isA<CompositionSuccess>());

    final events = await host.lifecycleDiagnostics.query(
      CompositionLifecycleEventQuery(
        correlationId: 'install-search',
        limit: 20,
      ),
    );
    expect(events, hasLength(4));
    expect(events.map((event) => event.status), everyElement(
      CompositionLifecycleStatus.succeeded,
    ));

    final owner = await host.lifecycleDiagnostics.ownerSummary('search-plugin');
    expect(owner, isNotNull);
    expect(owner!.state, CompositionOwnerState.active);
    expect(owner.eventCount, 4);
    expect(owner.failureCount, 0);
    expect(owner.lastFailure, isNull);

    await host.close();
  });

  test('overlays live events rejected by the persistence queue', () async {
    final host = JsonlCompositionLifecycleRuntime(
      file: file,
      maxPendingEvents: 1,
    );
    final transaction = host.runtime.beginTransaction(
      lifecycle: _Lifecycle(),
      correlationId: 'queue-overflow',
    )..stage(ServiceNode(serviceId: 'index', ownerId: 'search-plugin'));
    expect(transaction.commit(), isA<CompositionSuccess>());
    expect(host.rejectedEventCount, greaterThan(0));

    final events = await host.lifecycleDiagnostics.query(
      CompositionLifecycleEventQuery(
        correlationId: 'queue-overflow',
        limit: 20,
      ),
    );
    expect(events, hasLength(4));

    final owner = await host.lifecycleDiagnostics.ownerSummary('search-plugin');
    expect(owner, isNotNull);
    expect(owner!.eventCount, 4);

    await host.close();
  });

  test('aggregates durable owner history after runtime history is bounded', () async {
    final host = JsonlCompositionLifecycleRuntime(
      file: file,
      maxLifecycleEvents: 2,
    );

    for (var i = 0; i < 3; i++) {
      final transaction = host.runtime.beginTransaction(
        lifecycle: _Lifecycle(),
        correlationId: 'install-$i',
      )..stage(ServiceNode(
          serviceId: 'index-$i',
          ownerId: 'search-plugin',
        ));
      expect(transaction.commit(), isA<CompositionSuccess>());
    }

    expect(host.runtime.lifecycleEvents, hasLength(2));

    final owner = await host.lifecycleDiagnostics.ownerSummary('search-plugin');
    expect(owner, isNotNull);
    expect(owner!.eventCount, 12);
    expect(owner.failureCount, 0);

    final summaries = await host.lifecycleDiagnostics.ownerSummaries();
    expect(summaries, hasLength(1));
    expect(summaries.single.ownerId, 'search-plugin');
    expect(summaries.single.eventCount, 12);

    await host.close();
  });

  test('queries durable timeline with time and status filters', () async {
    final host = JsonlCompositionLifecycleRuntime(file: file);
    final transaction = host.runtime.beginTransaction(
      lifecycle: _Lifecycle(),
      correlationId: 'install-search',
    )..stage(ServiceNode(serviceId: 'index', ownerId: 'search-plugin'));
    transaction.commit();

    final all = await host.lifecycleDiagnostics.query(
      CompositionLifecycleEventQuery(limit: 20),
    );
    final start = all.first.timestamp;
    final filtered = await host.lifecycleDiagnostics.query(
      CompositionLifecycleEventQuery(
        ownerId: 'search-plugin',
        status: CompositionLifecycleStatus.succeeded,
        from: start,
        to: all.last.timestamp,
        limit: 20,
      ),
    );

    expect(filtered, hasLength(4));
    expect(filtered.every((event) => event.ownerIds.contains('search-plugin')), isTrue);

    await host.close();
  });

  test('returns null for an owner with no retained or durable activity', () async {
    final host = JsonlCompositionLifecycleRuntime(file: file);
    expect(await host.lifecycleDiagnostics.ownerSummary('missing'), isNull);
    expect(await host.lifecycleDiagnostics.ownerSummaries(), isEmpty);
    await host.close();
  });
}

class _Lifecycle implements CompositionLifecycle {
  @override
  void prepare(List<CompositionNode> orderedNodes) {}

  @override
  void activate(List<CompositionNode> orderedNodes) {}

  @override
  void deactivate(List<CompositionNode> reverseOrderedNodes) {}

  @override
  void compensate(
    List<CompositionNode> orderedNodes,
    Object error,
    StackTrace stackTrace,
  ) {}
}
