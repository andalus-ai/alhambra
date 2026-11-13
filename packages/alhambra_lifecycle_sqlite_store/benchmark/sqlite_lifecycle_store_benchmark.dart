import 'dart:io';

import 'package:alhambra_lifecycle_sqlite_store/alhambra_lifecycle_sqlite_store.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

/// Small repeatable smoke benchmark for local adapter comparisons.
///
/// Run from this package:
///   dart run benchmark/sqlite_lifecycle_store_benchmark.dart 10000
///
/// This is an observational harness, not a CI performance assertion. Record
/// machine, Dart, SQLite, filesystem, and event-count details with results.
Future<void> main(List<String> arguments) async {
  final count = arguments.isEmpty ? 10000 : int.parse(arguments.single);
  if (count <= 0) {
    stderr.writeln('Event count must be positive.');
    exitCode = 64;
    return;
  }

  final directory = await Directory.systemTemp.createTemp('alhambra-sqlite-bench-');
  final path = '${directory.path}/benchmark.sqlite';
  final store = SqliteCompositionLifecycleEventStore.open(path: path);
  try {
    final appendWatch = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      await store.append(
        CompositionLifecycleEvent(
          eventId: 'event-${i.toString().padLeft(10, '0')}',
          correlationId: 'correlation-${i % 100}',
          operation: CompositionLifecycleOperation.activate,
          status: i.isEven
              ? CompositionLifecycleStatus.succeeded
              : CompositionLifecycleStatus.failed,
          timestamp: DateTime.utc(2026, 1, 1).add(Duration(microseconds: i)),
          nodeIds: const ['benchmark:node'],
          ownerIds: ['owner-${i % 20}'],
        ),
      );
    }
    appendWatch.stop();

    final queryWatch = Stopwatch()..start();
    final page = await store.query(
      CompositionLifecycleEventQuery(
        ownerId: 'owner-7',
        status: CompositionLifecycleStatus.succeeded,
        limit: 100,
      ),
    );
    queryWatch.stop();

    final checkpoint = store.checkpoint();
    stdout.writeln('SQLite lifecycle store benchmark');
    stdout.writeln('events: $count');
    stdout.writeln('append_ms: ${(appendWatch.elapsedMicroseconds / 1000).toStringAsFixed(2)}');
    stdout.writeln('append_events_per_second: '
        '${(count / appendWatch.elapsedMicroseconds * 1000000).toStringAsFixed(1)}');
    stdout.writeln('filtered_query_ms: ${(queryWatch.elapsedMicroseconds / 1000).toStringAsFixed(2)}');
    stdout.writeln('filtered_query_results: ${page.length}');
    stdout.writeln('wal_busy: ${checkpoint.busy}');
    stdout.writeln('wal_log_frames: ${checkpoint.logFrames}');
    stdout.writeln('wal_checkpointed_frames: ${checkpoint.checkpointedFrames}');
  } finally {
    await store.close();
    await directory.delete(recursive: true);
  }
}
