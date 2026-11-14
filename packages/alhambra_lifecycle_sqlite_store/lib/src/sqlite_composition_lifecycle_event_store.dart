import 'dart:io';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:sqlite3/sqlite3.dart';

/// SQLite-backed lifecycle event store with transactional idempotent writes.
///
/// The adapter accepts a host-owned [Database] or can open and own one using
/// [SqliteCompositionLifecycleEventStore.open]. SQLite calls are synchronous.
/// UI hosts should use the isolate worker adapter to move database work
/// to a dedicated isolate.
final class SqliteCompositionLifecycleEventStore
    implements
        CompositionLifecycleEventStore,
        CompositionLifecycleStorageMaintenanceProvider {
  static const int schemaVersion = 2;

  static final List<_SqliteSchemaMigration> _migrations = [
    _SqliteSchemaMigration(version: 1, apply: _createInitialSchema),
    _SqliteSchemaMigration(version: 2, apply: _addCombinedStatusOperationIndex),
  ];

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

    final currentVersion =
        database.select('PRAGMA user_version').first['user_version'] as int;
    if (currentVersion > schemaVersion) {
      throw StateError(
        'Lifecycle database schema $currentVersion is newer than supported $schemaVersion.',
      );
    }

    for (final migration in _migrations) {
      if (migration.version <= currentVersion) continue;
      database.execute('BEGIN IMMEDIATE');
      try {
        migration.apply(database);
        database.execute('PRAGMA user_version = ${migration.version}');
        database.execute('COMMIT');
      } on Object {
        database.execute('ROLLBACK');
        rethrow;
      }
    }
  }

  static void _createInitialSchema(Database database) {
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
  }

  /// Adds an index for the common status + operation + chronological query.
  static void _addCombinedStatusOperationIndex(Database database) {
    database.execute(
      'CREATE INDEX IF NOT EXISTS idx_lifecycle_status_operation_time '
      'ON lifecycle_events(status, operation, timestamp_micros, event_id_sort_key)',
    );
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

  /// Removes events older than [retainFrom] and/or keeps only the newest
  /// [maxEvents] records.
  ///
  /// [retainFrom] is inclusive. When both policies are supplied, the time
  /// filter is applied first and [maxEvents] then caps the remaining newest
  /// records, ordered by (timestamp, event ID). Returns the number removed.
  ///
  /// Deletion and owner-association cleanup are atomic. This does not shrink
  /// the database file; use [checkpoint] for WAL maintenance and schedule
  /// VACUUM separately when reclaiming database-file space is necessary.
  Future<int> compact({
    DateTime? retainFrom,
    int? maxEvents,
  }) async {
    _ensureOpen();
    if (retainFrom == null && maxEvents == null) {
      throw ArgumentError('Provide retainFrom, maxEvents, or both.');
    }
    if (maxEvents != null && maxEvents < 1) {
      throw ArgumentError.value(maxEvents, 'maxEvents', 'Must be greater than zero.');
    }

    database.execute('BEGIN IMMEDIATE');
    try {
      final before = database.select(
        'SELECT COUNT(*) AS count FROM lifecycle_events',
      ).single['count'] as int;
      if (retainFrom != null) {
        database.execute(
          'DELETE FROM lifecycle_events WHERE timestamp_micros < ?',
          [retainFrom.toUtc().microsecondsSinceEpoch],
        );
      }
      if (maxEvents != null) {
        database.execute(
          'DELETE FROM lifecycle_events WHERE event_id NOT IN ('
          'SELECT event_id FROM lifecycle_events '
          'ORDER BY timestamp_micros DESC, event_id_sort_key DESC LIMIT ?'
          ')',
          [maxEvents],
        );
      }
      final after = database.select(
        'SELECT COUNT(*) AS count FROM lifecycle_events',
      ).single['count'] as int;
      database.execute('COMMIT');
      return before - after;
    } on Object {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<CompositionLifecycleStorageMaintenanceResult> maintain(
    CompositionLifecycleStorageMaintenanceRequest request,
  ) async {
    final startedAt = DateTime.now().toUtc();
    int? removed;
    if (request.retainFrom != null || request.maxEvents != null) {
      removed = await compact(
        retainFrom: request.retainFrom,
        maxEvents: request.maxEvents,
      );
    }

    SqliteWalCheckpointResult? checkpointResult;
    if (request.checkpoint) {
      checkpointResult = checkpoint();
    }
    final warnings = <String>[];
    if (checkpointResult != null && !checkpointResult.fullyCheckpointed) {
      warnings.add(
        'SQLite checkpoint was incomplete: busy=${checkpointResult.busy}, '
        'checkpointed=${checkpointResult.checkpointedFrames}/'
        '${checkpointResult.logFrames} frames.',
      );
    }
    return CompositionLifecycleStorageMaintenanceResult(
      startedAt: startedAt,
      completedAt: DateTime.now().toUtc(),
      recordsRemoved: removed,
      checkpointRequested: request.checkpoint,
      checkpointCompleted: checkpointResult?.fullyCheckpointed,
      warnings: warnings,
      metrics: {
        'adapter': 'sqlite',
        'checkpointMode': checkpointResult?.mode.name,
        'checkpointBusy': checkpointResult?.busy,
        'checkpointLogFrames': checkpointResult?.logFrames,
        'checkpointedFrames': checkpointResult?.checkpointedFrames,
      },
    );
  }

  /// Runs a SQLite WAL checkpoint and returns SQLite's checkpoint counters.
  SqliteWalCheckpointResult checkpoint({
    SqliteWalCheckpointMode mode = SqliteWalCheckpointMode.passive,
  }) {
    _ensureOpen();
    final row = database.select('PRAGMA wal_checkpoint(${mode.name.toUpperCase()})').single;
    return SqliteWalCheckpointResult(
      busy: row['busy'] as int,
      logFrames: row['log'] as int,
      checkpointedFrames: row['checkpointed'] as int,
      mode: mode,
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

/// Supported SQLite WAL checkpoint strategies.
enum SqliteWalCheckpointMode {
  /// Checkpoint without waiting for readers or writers.
  passive,

  /// Wait for readers to finish; allow writers to continue.
  full,

  /// Wait for readers and writers, then restart the WAL.
  restart,

  /// Truncate the WAL after checkpointing all possible frames.
  truncate,
}

/// Raw checkpoint counters returned by SQLite.
final class SqliteWalCheckpointResult {
  final int busy;
  final int logFrames;
  final int checkpointedFrames;
  final SqliteWalCheckpointMode mode;

  const SqliteWalCheckpointResult({
    required this.busy,
    required this.logFrames,
    required this.checkpointedFrames,
    required this.mode,
  });

  bool get fullyCheckpointed =>
      busy == 0 && logFrames >= 0 && checkpointedFrames == logFrames;
}

/// One ordered, transactional SQLite schema migration.
final class _SqliteSchemaMigration {
  final int version;
  final void Function(Database database) apply;

  const _SqliteSchemaMigration({
    required this.version,
    required this.apply,
  });
}
