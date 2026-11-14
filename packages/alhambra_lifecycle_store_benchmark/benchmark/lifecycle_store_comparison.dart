import 'dart:io';

import 'package:alhambra_lifecycle_file_store/alhambra_lifecycle_file_store.dart';
import 'package:alhambra_lifecycle_sqlite_store/alhambra_lifecycle_sqlite_store.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

/// Comparative benchmark for the JSONL and SQLite lifecycle adapters.
///
/// Run from this package:
///   dart run benchmark/lifecycle_store_comparison.dart 10000
///   dart run benchmark/lifecycle_store_comparison.dart 100000
///   dart run benchmark/lifecycle_store_comparison.dart 1000000
///
/// Results are observational, not CI thresholds. Run on an otherwise idle
/// machine and record Dart, SQLite, OS, filesystem, and hardware versions.
Future<void> main(List<String> arguments) async {
  final count = arguments.isEmpty ? 10000 : int.tryParse(arguments.single);
  if (count == null || count < 1) {
    stderr.writeln(
      'Usage: dart run benchmark/lifecycle_store_comparison.dart [positive-event-count]',
    );
    exitCode = 64;
    return;
  }

  final directory =
      await Directory.systemTemp.createTemp('alhambra-lifecycle-compare-');
  try {
    final jsonlDirectory = Directory('${directory.path}/jsonl');
    final sqliteDirectory = Directory('${directory.path}/sqlite');
    await jsonlDirectory.create();
    await sqliteDirectory.create();

    final jsonlFile = File('${jsonlDirectory.path}/lifecycle.jsonl');
    final sqlitePath = '${sqliteDirectory.path}/lifecycle.sqlite';
    final jsonl = _jsonlAdapter(jsonlFile);
    final sqlite = _sqliteAdapter(sqlitePath);

    stdout.writeln('Alhambra lifecycle store comparison');
    stdout.writeln('events: $count');
    stdout.writeln('dataset: deterministic-v1');
    stdout.writeln('query_samples: 30 (after one warm-up)');
    stdout.writeln();

    await _runAdapter(jsonl, count);
    stdout.writeln();
    await _runAdapter(sqlite, count);
  } finally {
    await directory.delete(recursive: true);
  }
}

Future<void> _runAdapter(_Adapter adapter, int count) async {
  var current = adapter;
  final appendWatch = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    await current.store.append(_event(i));
  }
  appendWatch.stop();

  final query = CompositionLifecycleEventQuery(
    ownerId: 'owner-${7}',
    status: CompositionLifecycleStatus.succeeded,
    limit: 100,
  );
  await current.store.query(query);
  final samples = <int>[];
  var resultCount = 0;
  for (var sample = 0; sample < 30; sample++) {
    final watch = Stopwatch()..start();
    final result = await current.store.query(query);
    watch.stop();
    resultCount = result.length;
    samples.add(watch.elapsedMicroseconds);
  }
  samples.sort();
  final p50 = samples[(samples.length * 0.50).floor()];
  final p95 = samples[(samples.length * 0.95).floor()];

  final bytesBeforeCompact = await current.measureBytes();
  final compactWatch = Stopwatch()..start();
  final removed = await current.compact((count * 9 / 10).floor().clamp(1, count).toInt());
  compactWatch.stop();
  final bytesAfterCompact = await current.measureBytes();

  final maintenance = await current.maintenance();
  await current.close();

  final restartWatch = Stopwatch()..start();
  current = current.reopen();
  await current.store.query(CompositionLifecycleEventQuery(limit: 1));
  restartWatch.stop();

  stdout.writeln('${adapter.name}');
  stdout.writeln('  append_ms: ${_ms(appendWatch.elapsedMicroseconds)}');
  stdout.writeln(
    '  append_events_per_second: '
    '${(count / appendWatch.elapsedMicroseconds * 1000000).toStringAsFixed(1)}',
  );
  stdout.writeln('  filtered_query_results: $resultCount');
  stdout.writeln('  filtered_query_p50_ms: ${_ms(p50)}');
  stdout.writeln('  filtered_query_p95_ms: ${_ms(p95)}');
  stdout.writeln('  bytes_before_compact: $bytesBeforeCompact');
  stdout.writeln('  compact_removed_events: $removed');
  stdout.writeln('  compact_ms: ${_ms(compactWatch.elapsedMicroseconds)}');
  stdout.writeln('  bytes_after_compact: $bytesAfterCompact');
  stdout.writeln('  reopen_and_first_query_ms: ${_ms(restartWatch.elapsedMicroseconds)}');
  for (final entry in maintenance.entries) {
    stdout.writeln('  ${entry.key}: ${entry.value}');
  }
  await current.close();
}

_Adapter _jsonlAdapter(File file) {
  final store = JsonlCompositionLifecycleEventStore(file: file);
  return _Adapter(
    name: 'JSONL (single-process file store)',
    store: store,
    compact: (maxEvents) => store.compact(maxEvents: maxEvents),
    close: () async {},
    reopen: () => _jsonlAdapter(file),
    measureBytes: () => _sumExistingFiles([
      file,
      File('${file.path}.sparse-index.json'),
    ]),
    maintenance: () async => const {'checkpoint': 'not applicable'},
  );
}

_Adapter _sqliteAdapter(String path) {
  final store = SqliteCompositionLifecycleEventStore.open(path: path);
  store.database.execute('PRAGMA wal_autocheckpoint = 0');
  return _Adapter(
    name: 'SQLite (WAL)',
    store: store,
    compact: (maxEvents) => store.compact(maxEvents: maxEvents),
    close: store.close,
    reopen: () => _sqliteAdapter(path),
    measureBytes: () => _sumExistingFiles([
      File(path),
      File('$path-wal'),
      File('$path-shm'),
    ]),
    maintenance: () async {
      final result = store.checkpoint();
      return {
        'wal_busy': result.busy,
        'wal_log_frames': result.logFrames,
        'wal_checkpointed_frames': result.checkpointedFrames,
        'wal_fully_checkpointed': result.fullyCheckpointed,
      };
    },
  );
}

Future<int> _sumExistingFiles(List<File> files) async {
  var total = 0;
  for (final file in files) {
    if (await file.exists()) total += await file.length();
  }
  return total;
}

CompositionLifecycleEvent _event(int index) {
  final status = index % 4 == 0
      ? CompositionLifecycleStatus.failed
      : CompositionLifecycleStatus.succeeded;
  return CompositionLifecycleEvent(
    eventId: 'event-${index.toString().padLeft(10, '0')}',
    correlationId: 'correlation-${index % 100}',
    operation: index.isEven
        ? CompositionLifecycleOperation.activate
        : CompositionLifecycleOperation.deactivate,
    status: status,
    timestamp: DateTime.utc(2026, 1, 1).add(Duration(microseconds: index)),
    nodeIds: ['benchmark:node-${index % 8}'],
    ownerIds: ['owner-${index % 20}'],
    duration: Duration(microseconds: index % 5000),
    errorType: status == CompositionLifecycleStatus.failed ? 'BenchmarkError' : null,
    errorMessage: status == CompositionLifecycleStatus.failed
        ? 'Deterministic benchmark failure'
        : null,
  );
}

String _ms(int microseconds) =>
    (microseconds / 1000).toStringAsFixed(3);

final class _Adapter {
  final String name;
  final CompositionLifecycleEventStore store;
  final Future<int> Function(int maxEvents) compact;
  final Future<void> Function() close;
  final _Adapter Function() reopen;
  final Future<int> Function() measureBytes;
  final Future<Map<String, Object>> Function() maintenance;

  const _Adapter({
    required this.name,
    required this.store,
    required this.compact,
    required this.close,
    required this.reopen,
    required this.measureBytes,
    required this.maintenance,
  });
}
