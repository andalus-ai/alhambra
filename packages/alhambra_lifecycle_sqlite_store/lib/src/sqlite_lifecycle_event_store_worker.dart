import 'dart:async';
import 'dart:isolate';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

import 'sqlite_composition_lifecycle_event_store.dart';

/// A lifecycle event store whose SQLite connection is owned by a worker
/// isolate. No SQLite object crosses the isolate boundary.
///
/// The public API is identical to the synchronous adapter. Requests are
/// serialized through one command port, preserving append order and ensuring
/// that a single SQLite connection is never used concurrently.
final class SqliteLifecycleEventStoreWorker
    implements CompositionLifecycleEventStore {
  final ReceivePort _responses;
  final ReceivePort _errors;
  final ReceivePort _exits;
  final Isolate _isolate;
  final SendPort _commands;
  final StreamSubscription<Object?> _responseSubscription;
  final StreamSubscription<Object?> _errorSubscription;
  final StreamSubscription<Object?> _exitSubscription;
  final Map<int, Completer<Map<Object?, Object?>>> _pending;
  int _nextRequestId = 0;
  bool _closing = false;
  bool _closed = false;

  SqliteLifecycleEventStoreWorker._({
    required ReceivePort responses,
    required ReceivePort errors,
    required ReceivePort exits,
    required Isolate isolate,
    required SendPort commands,
    required StreamSubscription<Object?> responseSubscription,
    required StreamSubscription<Object?> errorSubscription,
    required StreamSubscription<Object?> exitSubscription,
    required Map<int, Completer<Map<Object?, Object?>>> pending,
  })  : _responses = responses,
        _errors = errors,
        _exits = exits,
        _isolate = isolate,
        _commands = commands,
        _responseSubscription = responseSubscription,
        _errorSubscription = errorSubscription,
        _exitSubscription = exitSubscription,
        _pending = pending;

  /// Starts a dedicated isolate and opens [path] inside that isolate.
  ///
  /// The returned future completes only after the worker has opened SQLite,
  /// applied schema checks, and sent its command port to the host.
  static Future<SqliteLifecycleEventStoreWorker> open({
    required String path,
  }) async {
    final responses = ReceivePort();
    final errors = ReceivePort();
    final exits = ReceivePort();
    final ready = Completer<SendPort>();
    final pending = <int, Completer<Map<Object?, Object?>>>{};
    final isolate = await Isolate.spawn<List<Object?>>(
      _sqliteLifecycleWorkerMain,
      <Object?>[responses.sendPort, path],
      onError: errors.sendPort,
      onExit: exits.sendPort,
      errorsAreFatal: true,
    );

    late StreamSubscription<Object?> responseSubscription;
    late StreamSubscription<Object?> errorSubscription;
    late StreamSubscription<Object?> exitSubscription;

    responseSubscription = responses.listen((message) {
      if (message is! Map) return;
      if (message['type'] == 'ready') {
        final port = message['port'];
        if (port is SendPort && !ready.isCompleted) ready.complete(port);
        return;
      }
      final id = message['id'];
      if (id is! int) return;
      final completer = pending.remove(id);
      if (completer != null && !completer.isCompleted) {
        completer.complete(Map<Object?, Object?>.from(message));
      }
    });

    errorSubscription = errors.listen((message) {
      final error = StateError('SQLite lifecycle worker failed to start: $message');
      if (!ready.isCompleted) ready.completeError(error);
      for (final completer in pending.values) {
        if (!completer.isCompleted) completer.completeError(error);
      }
      pending.clear();
    });

    exitSubscription = exits.listen((_) {
      final error = StateError('SQLite lifecycle worker exited unexpectedly.');
      if (!ready.isCompleted) ready.completeError(error);
      for (final completer in pending.values) {
        if (!completer.isCompleted) completer.completeError(error);
      }
      pending.clear();
    });

    try {
      final commandPort = await ready.future;
      return SqliteLifecycleEventStoreWorker._(
        responses: responses,
        errors: errors,
        exits: exits,
        isolate: isolate,
        commands: commandPort,
        responseSubscription: responseSubscription,
        errorSubscription: errorSubscription,
        exitSubscription: exitSubscription,
        pending: pending,
      );
    } catch (_) {
      isolate.kill(priority: Isolate.immediate);
      await responseSubscription.cancel();
      await errorSubscription.cancel();
      await exitSubscription.cancel();
      responses.close();
      errors.close();
      exits.close();
      rethrow;
    }
  }

  Future<Map<Object?, Object?>> _request(
    String operation, [
    Map<String, Object?> payload = const {},
  ]) async {
    if (_closed || (_closing && operation != 'close')) {
      throw StateError('SQLite lifecycle worker is closed or closing.');
    }
    final id = ++_nextRequestId;
    final completer = Completer<Map<Object?, Object?>>();
    _pending[id] = completer;
    _commands.send(<String, Object?>{
      'id': id,
      'operation': operation,
      'payload': payload,
    });
    final response = await completer.future;
    if (response['ok'] != true) {
      final type = response['errorType'];
      final message = response['errorMessage']?.toString() ?? 'Unknown worker error';
      if (type == 'CompositionLifecycleEventIdentityConflictException') {
        throw CompositionLifecycleEventIdentityConflictException(
          response['eventId']?.toString() ?? '',
        );
      }
      throw StateError('$type: $message');
    }
    return response;
  }

  @override
  Future<void> append(CompositionLifecycleEvent event) async {
    await _request('append', <String, Object?>{
      'event': const CompositionLifecycleEventJsonCodec().encode(event),
    });
  }

  @override
  Future<List<CompositionLifecycleEvent>> query(
    CompositionLifecycleEventQuery query,
  ) async {
    final response = await _request('query', <String, Object?>{
      'query': _encodeQuery(query),
    });
    final values = response['events'] as List<Object?>;
    const codec = CompositionLifecycleEventJsonCodec();
    return List<CompositionLifecycleEvent>.unmodifiable(
      values.map((value) => codec.decode(value as String)),
    );
  }

  /// Requests a WAL checkpoint without closing the worker.
  Future<SqliteWalCheckpointResult> checkpoint({
    SqliteWalCheckpointMode mode = SqliteWalCheckpointMode.passive,
  }) async {
    final response = await _request('checkpoint', {'mode': mode.name});
    return SqliteWalCheckpointResult(
      busy: response['busy'] as int,
      logFrames: response['logFrames'] as int,
      checkpointedFrames: response['checkpointedFrames'] as int,
      mode: mode,
    );
  }

  /// Flushes and closes SQLite, then terminates the worker isolate.
  Future<void> close() async {
    if (_closed || _closing) return;
    _closing = true;
    try {
      await _request('close');
    } finally {
      _closed = true;
      _isolate.kill(priority: Isolate.immediate);
      await _responseSubscription.cancel();
      await _errorSubscription.cancel();
      await _exitSubscription.cancel();
      _responses.close();
      _errors.close();
      _exits.close();
    }
  }
}

Map<String, Object?> _encodeQuery(CompositionLifecycleEventQuery query) => {
      'correlationId': query.correlationId,
      'ownerId': query.ownerId,
      'operation': query.operation?.name,
      'status': query.status?.name,
      'from': query.from?.toIso8601String(),
      'to': query.to?.toIso8601String(),
      'before': query.before?.toIso8601String(),
      'after': query.after == null
          ? null
          : {
              'timestamp': query.after!.timestamp.toIso8601String(),
              'eventId': query.after!.eventId,
            },
      'beforeCursor': query.beforeCursor == null
          ? null
          : {
              'timestamp': query.beforeCursor!.timestamp.toIso8601String(),
              'eventId': query.beforeCursor!.eventId,
            },
      'limit': query.limit,
    };

CompositionLifecycleEventQuery _decodeQuery(Map<Object?, Object?> value) {
  Map<Object?, Object?>? cursor(String key) {
    final raw = value[key];
    return raw is Map ? Map<Object?, Object?>.from(raw) : null;
  }

  CompositionLifecycleEventCursor? decodeCursor(String key) {
    final raw = cursor(key);
    if (raw == null) return null;
    return CompositionLifecycleEventCursor(
      timestamp: DateTime.parse(raw['timestamp'] as String),
      eventId: raw['eventId'] as String,
    );
  }

  return CompositionLifecycleEventQuery(
    correlationId: value['correlationId'] as String?,
    ownerId: value['ownerId'] as String?,
    operation: value['operation'] == null
        ? null
        : CompositionLifecycleOperation.values.byName(value['operation'] as String),
    status: value['status'] == null
        ? null
        : CompositionLifecycleStatus.values.byName(value['status'] as String),
    from: value['from'] == null ? null : DateTime.parse(value['from'] as String),
    to: value['to'] == null ? null : DateTime.parse(value['to'] as String),
    before: value['before'] == null
        ? null
        : DateTime.parse(value['before'] as String),
    after: decodeCursor('after'),
    beforeCursor: decodeCursor('beforeCursor'),
    limit: value['limit'] as int,
  );
}

Future<void> _sqliteLifecycleWorkerMain(List<Object?> arguments) async {
  final host = arguments[0] as SendPort;
  final path = arguments[1] as String;
  final commands = ReceivePort();
  final store = SqliteCompositionLifecycleEventStore.open(path: path);
  host.send({'type': 'ready', 'port': commands.sendPort});

  await for (final raw in commands) {
    if (raw is! Map) continue;
    final id = raw['id'] as int;
    final operation = raw['operation'] as String;
    final payload = raw['payload'] is Map
        ? Map<Object?, Object?>.from(raw['payload'] as Map)
        : <Object?, Object?>{};
    try {
      switch (operation) {
        case 'append':
          await store.append(
            const CompositionLifecycleEventJsonCodec().decode(
              payload['event'] as String,
            ),
          );
          host.send({'id': id, 'ok': true});
          break;
        case 'query':
          final query = _decodeQuery(
            Map<Object?, Object?>.from(payload['query'] as Map),
          );
          const codec = CompositionLifecycleEventJsonCodec();
          final events = await store.query(query);
          host.send({
            'id': id,
            'ok': true,
            'events': events.map(codec.encode).toList(growable: false),
          });
          break;
        case 'checkpoint':
          final mode = SqliteWalCheckpointMode.values.byName(payload['mode'] as String);
          final result = store.checkpoint(mode: mode);
          host.send({
            'id': id,
            'ok': true,
            'busy': result.busy,
            'logFrames': result.logFrames,
            'checkpointedFrames': result.checkpointedFrames,
          });
          break;
        case 'close':
          await store.close();
          host.send({'id': id, 'ok': true});
          // Keep the command port alive until the host receives this ack;
          // the host then terminates the now-idle isolate.
          break;
        default:
          throw ArgumentError.value(operation, 'operation', 'Unknown worker command.');
      }
    } on Object catch (error) {
      host.send({
        'id': id,
        'ok': false,
        'errorType': error.runtimeType.toString(),
        'errorMessage': error.toString(),
        if (error is CompositionLifecycleEventIdentityConflictException)
          'eventId': error.eventId,
      });
    }
  }
}
