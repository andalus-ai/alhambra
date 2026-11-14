import 'dart:io';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:sqlite3/sqlite3.dart';

/// SQLite-backed lifecycle event store with transactional idempotent writes.
///
/// The adapter accepts a host-owned [Database] or can open and own one using
/// [SqliteCompositionLifecycleEventStore.open]. SQLite calls are synchronous;
/// applications with latency-sensitive UI threads should host the database
/// on a dedicated isolate and communicate with it through their own adapter.
final class SqliteCompositionLifecycleEventStore
    implements CompositionLifecycleEventStore {
  static const int schemaVersion = 1;

  final Database database;
  final CompositionLifecycleEventJsonCodec codec;
  final bool _ownsDatabase;
  bool _closed = false;

  SqliteCompositionLifecycleEventStore({
    required this.database,
    CompositionLifecycleEventJsonCodec? codec,
  })  : codec = codec ?? const CompositionLifecycleEventJsonCodec(),
        _ownsDatabase = false {
    _configure();
  }

  SqliteCompositionLifecycleEventStore._owned({
    required this.database,
    CompositionLifecycleEventJsonCodec? codec,
  })  : codec = codec ?? const CompositionLifecycleEventJsonCodec(),
        _ownsDatabase = true {
    _configure();
  }

  /// Opens a database at [path] and transfers ownership to this store.
  factory SqliteCompositionLifecycleEventStore.open({
    required String path,
    CompositionLifecycleEventJsonCodec? codec,
  }) {
    File(path).parent.createSync(recursive: true);
    final database = sqlite3.open(path);
    try {
      return SqliteCompositionLifecycleEventStore._owned(
        database: database,
        codec: codec,
      );
    } on Object {
      database.dispose();
      rethrow;
    }
  }

  void _configure() {
    database.execute('PRAGMA foreign_keys = ON');
    database.execute('PRAGMA busy_timeout = 5000');
    database.execute('PRAGMA journal_mode = WAL');

    final version = database.select('PRAGMA user_version').first['user_version'] as int;
    if (version > schemaVersion) {
      throw StateError(
        'Lifecycle database schema $version is newer than supported $schemaVersion.',
      );
    }
    if (version == 0) _createSchema();
  }

  void _createSchema() {
    database.execute('BEGIN IMMEDIATE');
    try {
      database.execute('''
        CREATE TABLE IF NOT EXISTS lifecycle_events (
          event_id TEXT PRIMARY KEY NOT NULL,
          event_id_sort_key TEXT NOT NULL,
          correlation_id TEXT NOT NULL,
          operation TEXT NOT NULL,
          status TEXT NOT NULL,
          timestamp_micros INTEGER NOT NULL,
          payload TEXT NOT NULL
        )
      ''');
      database.execute('''
        CREATE TABLE IF NOT EXISTS lifecycle_event_owners (
          event_id TEXT NOT NULL,
          owner_id TEXT NOT NULL,
          PRIMARY KEY (event_id, owner_id),
          FOREIGN KEY (event_id) REFERENCES lifecycle_events(event_id)
            ON DELETE CASCADE
        )
      ''');
      database.execute(
        'CREATE INDEX IF NOT EXISTS idx_lifecycle_time '
        'ON lifecycle_events(timestamp_micros, event_id_sort_key)',
      );
      database.execute(
        'CREATE INDEX IF NOT EXISTS idx_lifecycle_correlation_time '
        'ON lifecycle_events(correlation_id, timestamp_micros, event_id_sort_key)',
      );
      database.execute(
        'CREATE INDEX IF NOT EXISTS idx_lifecycle_operation_time '
        'ON lifecycle_events(operation, timestamp_micros, event_id_sort_key)',
      );
      database.execute(
        'CREATE INDEX IF NOT EXISTS idx_lifecycle_status_time '
        'ON lifecycle_events(status, timestamp_micros, event_id_sort_key)',
      );
      database.execute(
        'CREATE INDEX IF NOT EXISTS idx_lifecycle_owner_time '
        'ON lifecycle_event_owners(owner_id, event_id)',
      );
      database.execute('PRAGMA user_version = $schemaVersion');
      database.execute('COMMIT');
    } on Object {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<void> append(CompositionLifecycleEvent event) async {
    _ensureOpen();
    final payload = codec.encode(event);
    database.execute('BEGIN IMMEDIATE');
    try {
      final existing = database.select(
        'SELECT payload FROM lifecycle_events WHERE event_id = ?',
        [event.eventId],
      );
      if (existing.isNotEmpty) {
        if (existing.first['payload'] == payload) {
          database.execute('COMMIT');
          return;
        }
        throw CompositionLifecycleEventIdentityConflictException(event.eventId);
      }

      database.execute(
        'INSERT INTO lifecycle_events '
        '(event_id, event_id_sort_key, correlation_id, operation, status, timestamp_micros, payload) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          event.eventId,
          _eventIdSortKey(event.eventId),
          event.correlationId,
          event.operation.name,
          event.status.name,
          event.timestamp.toUtc().microsecondsSinceEpoch,
          payload,
        ],
      );
      for (final ownerId in event.ownerIds.toSet()) {
        database.execute(
          'INSERT INTO lifecycle_event_owners (event_id, owner_id) VALUES (?, ?)',
          [event.eventId, ownerId],
        );
      }
      database.execute('COMMIT');
    } on Object {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<List<CompositionLifecycleEvent>> query(
    CompositionLifecycleEventQuery query,
  ) async {
    _ensureOpen();
    final clauses = <String>[];
    final parameters = <Object?>[];

    void add(String clause, Object? value) {
      clauses.add(clause);
      parameters.add(value);
    }

    if (query.correlationId != null) {
      add('e.correlation_id = ?', query.correlationId);
    }
    if (query.operation != null) {
      add('e.operation = ?', query.operation!.name);
    }
    if (query.status != null) {
      add('e.status = ?', query.status!.name);
    }
    if (query.ownerId != null) {
      clauses.add('EXISTS (SELECT 1 FROM lifecycle_event_owners o '
          'WHERE o.event_id = e.event_id AND o.owner_id = ?)');
      parameters.add(query.ownerId);
    }
    if (query.from != null) {
      add('e.timestamp_micros >= ?', query.from!.toUtc().microsecondsSinceEpoch);
    }
    if (query.to != null) {
      add('e.timestamp_micros <= ?', query.to!.toUtc().microsecondsSinceEpoch);
    }
    if (query.before != null) {
      add('e.timestamp_micros < ?', query.before!.toUtc().microsecondsSinceEpoch);
    }
    if (query.after != null) {
      clauses.add('(e.timestamp_micros > ? OR '
          '(e.timestamp_micros = ? AND e.event_id_sort_key > ?))');
      final cursor = query.after!;
      parameters
        ..add(cursor.timestamp.toUtc().microsecondsSinceEpoch)
        ..add(cursor.timestamp.toUtc().microsecondsSinceEpoch)
        ..add(_eventIdSortKey(cursor.eventId));
    }
    if (query.beforeCursor != null) {
      clauses.add('(e.timestamp_micros < ? OR '
          '(e.timestamp_micros = ? AND e.event_id_sort_key < ?))');
      final cursor = query.beforeCursor!;
      parameters
        ..add(cursor.timestamp.toUtc().microsecondsSinceEpoch)
        ..add(cursor.timestamp.toUtc().microsecondsSinceEpoch)
        ..add(_eventIdSortKey(cursor.eventId));
    }

    final backward = query.beforeCursor != null;
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    parameters.add(query.limit);
    final rows = database.select(
      'SELECT e.payload FROM lifecycle_events e $where '
      'ORDER BY e.timestamp_micros ${backward ? 'DESC' : 'ASC'}, '
      'e.event_id_sort_key ${backward ? 'DESC' : 'ASC'} LIMIT ?',
      parameters,
    );

    final events = rows
        .map((row) => codec.decode(row['payload'] as String))
        .toList(growable: false);
    return List<CompositionLifecycleEvent>.unmodifiable(
      backward ? events.reversed.toList(growable: false) : events,
    );
  }

  /// Closes the database only when this store opened and owns it.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (_ownsDatabase) database.dispose();
  }

  void _ensureOpen() {
    if (_closed) throw StateError('Lifecycle SQLite store is closed.');
  }
}


String _eventIdSortKey(String value) => value.codeUnits
    .map((unit) => unit.toRadixString(16).padLeft(4, '0'))
    .join();
