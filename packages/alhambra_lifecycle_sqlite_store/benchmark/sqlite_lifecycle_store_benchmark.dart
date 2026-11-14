import 'dart:io';

import 'package:alhambra_lifecycle_sqlite_store/alhambra_lifecycle_sqlite_store.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

/// Repeatable observational benchmark for SQLite lifecycle storage.
///
/// Run from this package:
///   dart run benchmark/sqlite_lifecycle_store_benchmark.dart 10000
///   dart run benchmark/sqlite_lifecycle_store_benchmark.dart 100000
///   dart run benchmark/sqlite_lifecycle_store_benchmark.dart 1000000
///
/// This is not a CI performance assertion. Record machine, Dart/SQLite
/// versions, filesystem, and event count when comparing results.
Future<void> main(List<String> arguments) async {
  final count = arguments.isEmpty ? 10000 : int.tryParse(arguments.single);
  if (count == null || count <= 0) {
    stderr.writeln('Usage: dart run benchmark/sqlite_lifecycle_store_benchmark.dart [positive-event-count]');
    exitCode = 64;
    return;
  }

  final directory = await Directory.systemTemp.createTemp('alhambra-sqlite-bench-');
  final path = '${directory.path}/benchmark.sqlite';
  final store = SqliteCompositionLifecycleEventStore.open(path: path);
  try {
    store.database.execute('PRAGMA wal_autocheckpoint = 0');
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

    final query = CompositionLifecycleEventQuery(
      ownerId: 'owner-7',
      status: CompositionLifecycleStatus.succeeded,
      limit: 100,
    );
    // Warm the SQLite page cache and statement path before collecting samples.
    await store.query(query);
    final querySamplesMicros = <int>[];
    var pageLength = 0;
    for (var sample = 0; sample < 30; sample++) {
      final watch = Stopwatch()..start();
      final page = await store.query(query);
      watch.stop();
      pageLength = page.length;
      querySamplesMicros.add(watch.elapsedMicroseconds);
    }
    querySamplesMicros.sort();
    final p50 = querySamplesMicros[(querySamplesMicros.length * 0.50).floor()];
    final p95 = querySamplesMicros[(querySamplesMicros.length * 0.95).floor()];

    final walFile = File('$path-wal');
    final databaseBytes = await File(path).length();
    final walBytesBeforeCheckpoint =
        await walFile.exists() ? await walFile.length() : 0;
    final checkpoint = store.checkpoint();

    stdout.writeln('SQLite lifecycle store benchmark');
    stdout.writeln('events: $count');
    stdout.writeln('append_ms: ${(appendWatch.elapsedMicroseconds / 1000).toStringAsFixed(2)}');
    stdout.writeln('append_events_per_second: '
        '${(count / appendWatch.elapsedMicroseconds * 1000000).toStringAsFixed(1)}');
    stdout.writeln('filtered_query_samples: ${querySamplesMicros.length}');
    stdout.writeln('filtered_query_results: $pageLength');
    stdout.writeln('filtered_query_p50_ms: ${(p50 / 1000).toStringAsFixed(3)}');
    stdout.writeln('filtered_query_p95_ms: ${(p95 / 1000).toStringAsFixed(3)}');
    stdout.writeln('database_bytes_before_checkpoint: $databaseBytes');
    stdout.writeln('wal_bytes_before_checkpoint: $walBytesBeforeCheckpoint');
    stdout.writeln('wal_busy: ${checkpoint.busy}');
    stdout.writeln('wal_log_frames: ${checkpoint.logFrames}');
    stdout.writeln('wal_checkpointed_frames: ${checkpoint.checkpointedFrames}');
    stdout.writeln('wal_fully_checkpointed: ${checkpoint.fullyCheckpointed}');
  } finally {
    await store.close();
    await directory.delete(recursive: true);
  }
}
