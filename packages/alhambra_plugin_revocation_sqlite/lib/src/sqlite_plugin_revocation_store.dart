import 'dart:math';

import 'package:sqlite3/sqlite3.dart' as sq;
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

/// SQLite-backed implementation of the revocation execution, journal and
/// outbox contracts. Each write transaction is acquired with BEGIN IMMEDIATE
/// so independent connections/processes serialize claims and CAS updates.
///
/// The database must be on a filesystem that supports SQLite locking. Do not
/// place a live SQLite database on an object store or an unreliable network FS.
final class SqlitePluginRevocationStore
    implements
        TransactionalPluginRevocationStore,
        PluginRevocationOutboxStore,
        PluginRevocationOutboxInspectionStore {
  final sq.Database _db;
  final Random _random;
  bool _closed = false;

  /// Journal view sharing this adapter's SQLite connection.
  PluginRevocationJournalStore get journalStore =>
      _SqlitePluginRevocationJournalStore(this);

  SqlitePluginRevocationStore(
    String path, {
    Random? random,
  })  : _db = sq.sqlite3.open(path),
        _random = random ?? Random.secure() {
    _db.execute('PRAGMA busy_timeout = 5000');
    if (path != ':memory:') _db.execute('PRAGMA journal_mode = WAL');
    _db.execute('PRAGMA foreign_keys = ON');
    _migrate();
  }

  /// Create a private in-memory store, primarily for tests.
  SqlitePluginRevocationStore.memory({Random? random})
      : _db = sq.sqlite3.openInMemory(),
        _random = random ?? Random.secure() {
    _db.execute('PRAGMA foreign_keys = ON');
    _migrate();
  }

  void close() {
    if (_closed) return;
    _db.dispose();
    _closed = true;
  }

  void _assertOpen() {
    if (_closed) throw StateError('SQLite revocation store is closed.');
  }

  void _migrate() {
    final version =
        _db.select('PRAGMA user_version').first['user_version'] as int;
    if (version > 1) {
      throw UnsupportedError(
        'Database schema version $version is newer than this adapter supports.',
      );
    }
    if (version == 1) return;

    _db.execute('''
      CREATE TABLE IF NOT EXISTS plugin_revocation_execution (
        idempotency_key TEXT PRIMARY KEY,
        operation_id TEXT NOT NULL,
        plugin_id TEXT NOT NULL,
        provider_owner_id TEXT NOT NULL,
        action TEXT NOT NULL,
        status TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        detail TEXT
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS plugin_revocation_outbox (
        event_id TEXT PRIMARY KEY,
        idempotency_key TEXT NOT NULL UNIQUE,
        operation_id TEXT NOT NULL,
        plugin_id TEXT NOT NULL,
        provider_owner_id TEXT NOT NULL,
        action TEXT NOT NULL,
        outcome TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        detail TEXT,
        state TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        next_attempt_at TEXT NOT NULL,
        lease_owner TEXT,
        lease_token TEXT,
        lease_until TEXT,
        delivered_at TEXT,
        last_error_code TEXT
      )
    ''');
    _db.execute('''
      CREATE INDEX IF NOT EXISTS idx_plugin_revocation_outbox_due
      ON plugin_revocation_outbox(state, next_attempt_at, lease_until, occurred_at)
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS plugin_revocation_journal (
        idempotency_key TEXT PRIMARY KEY,
        schema_version INTEGER NOT NULL,
        operation_id TEXT NOT NULL,
        plugin_id TEXT NOT NULL,
        provider_owner_id TEXT NOT NULL,
        action TEXT NOT NULL,
        status TEXT NOT NULL,
        revision INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        correlation_id TEXT,
        detail TEXT
      )
    ''');
    _db.execute('PRAGMA user_version = 1');
  }

  T _transaction<T>(T Function() action) {
    _assertOpen();
    _db.execute('BEGIN IMMEDIATE');
    try {
      final result = action();
      _db.execute('COMMIT');
      return result;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  static String _date(DateTime value) => value.toUtc().toIso8601String();
  static DateTime _parseDate(Object? value) =>
      DateTime.parse(value! as String).toUtc();

  static PluginRevocationExecutionRecord _execution(
    Map<String, Object?> row,
  ) =>
      PluginRevocationExecutionRecord(
        idempotencyKey: row['idempotency_key']! as String,
        operationId: row['operation_id']! as String,
        pluginId: row['plugin_id']! as String,
        providerOwnerId: row['provider_owner_id']! as String,
        action: CapabilityImpactAction.values.byName(row['action']! as String),
        status: PluginRevocationExecutionStatus.values
            .byName(row['status']! as String),
        updatedAt: _parseDate(row['updated_at']),
        detail: row['detail'] as String?,
      );

  static PluginRevocationAuditEvent _event(Map<String, Object?> row) =>
      PluginRevocationAuditEvent(
        eventId: row['event_id']! as String,
        idempotencyKey: row['idempotency_key']! as String,
        operationId: row['operation_id']! as String,
        pluginId: row['plugin_id']! as String,
        providerOwnerId: row['provider_owner_id']! as String,
        action: row['action']! as String,
        outcome: row['outcome']! as String,
        occurredAt: _parseDate(row['occurred_at']),
        detail: row['detail'] as String?,
      );

  static PluginRevocationOutboxMessage _message(
    Map<String, Object?> row,
  ) =>
      PluginRevocationOutboxMessage(
        event: _event(row),
        state: PluginRevocationOutboxState.values
            .byName(row['state']! as String),
        attempts: row['attempts']! as int,
        nextAttemptAt: _parseDate(row['next_attempt_at']),
        leaseOwner: row['lease_owner'] as String?,
        leaseToken: row['lease_token'] as String?,
        leaseUntil: row['lease_until'] == null
            ? null
            : _parseDate(row['lease_until']),
        deliveredAt: row['delivered_at'] == null
            ? null
            : _parseDate(row['delivered_at']),
        lastErrorCode: row['last_error_code'] as String?,
      );

  @override
  Future<PluginRevocationExecutionRecord?> read(String idempotencyKey) async {
    _assertOpen();
    final rows = _db.select(
      'SELECT * FROM plugin_revocation_execution WHERE idempotency_key = ?',
      [idempotencyKey],
    );
    return rows.isEmpty ? null : _execution(rows.first);
  }

  @override
  Future<bool> writePending(PluginRevocationExecutionRecord record) async =>
      _transaction(() {
        _db.execute('''
          INSERT OR IGNORE INTO plugin_revocation_execution
          (idempotency_key, operation_id, plugin_id, provider_owner_id,
           action, status, updated_at, detail)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          record.idempotencyKey,
          record.operationId,
          record.pluginId,
          record.providerOwnerId,
          record.action.name,
          record.status.name,
          _date(record.updatedAt),
          record.detail,
        ]);
        final inserted =
            _db.select('SELECT changes() AS count').first['count'] as int;
        if (inserted != 1) return false;

        _db.execute('''
          INSERT INTO plugin_revocation_journal
          (idempotency_key, schema_version, operation_id, plugin_id,
           provider_owner_id, action, status, revision, created_at,
           updated_at, detail)
          VALUES (?, ?, ?, ?, ?, ?, 'pending', 1, ?, ?, ?)
        ''', [
          record.idempotencyKey,
          PluginRevocationJournalEntry.currentSchemaVersion,
          record.operationId,
          record.pluginId,
          record.providerOwnerId,
          record.action.name,
          _date(record.updatedAt),
          _date(record.updatedAt),
          record.detail,
        ]);
        return true;
      });

  @override
  Future<void> complete(PluginRevocationExecutionRecord record) async {
    await completeAndEnqueue(record);
  }

  @override
  Future<void> append(PluginRevocationExecutionRecord record) async {
    _assertOpen();
    _transaction(() {
      _enqueue(record);
    });
  }

  void _enqueue(PluginRevocationExecutionRecord record) {
    final eventId = '${record.idempotencyKey}:terminal';
    _db.execute('''
      INSERT OR IGNORE INTO plugin_revocation_outbox
      (event_id, idempotency_key, operation_id, plugin_id, provider_owner_id,
       action, outcome, occurred_at, detail, state, attempts, next_attempt_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', 0, ?)
    ''', [
      eventId,
      record.idempotencyKey,
      record.operationId,
      record.pluginId,
      record.providerOwnerId,
      record.action.name,
      record.status.name,
      _date(record.updatedAt),
      record.detail,
      _date(record.updatedAt),
    ]);
  }

  @override
  Future<void> completeAndEnqueue(
    PluginRevocationExecutionRecord record,
  ) async {
    _transaction(() {
      _db.execute('''
        UPDATE plugin_revocation_execution
        SET operation_id = ?, plugin_id = ?, provider_owner_id = ?,
            action = ?, status = ?, updated_at = ?, detail = ?
        WHERE idempotency_key = ?
      ''', [
        record.operationId,
        record.pluginId,
        record.providerOwnerId,
        record.action.name,
        record.status.name,
        _date(record.updatedAt),
        record.detail,
        record.idempotencyKey,
      ]);
      final executionChanged =
          _db.select('SELECT changes() AS count').first['count'] as int;
      if (executionChanged != 1) {
        throw StateError('Cannot complete an unclaimed revocation operation.');
      }

      _db.execute('''
        UPDATE plugin_revocation_journal
        SET status = ?, revision = revision + 1, updated_at = ?, detail = ?
        WHERE idempotency_key = ?
      ''', [
        _journalStatus(record.status).name,
        _date(record.updatedAt),
        record.detail,
        record.idempotencyKey,
      ]);
      final journalChanged =
          _db.select('SELECT changes() AS count').first['count'] as int;
      if (journalChanged != 1) {
        throw StateError(
          'Revocation journal row is missing; transaction rolled back.',
        );
      }
      _enqueue(record);
    });
  }

  @override
  Future<List<PluginRevocationOutboxMessage>> readAllOutbox() async {
    _assertOpen();
    final rows = _db.select(
      'SELECT * FROM plugin_revocation_outbox ORDER BY occurred_at, event_id',
    );
    return List.unmodifiable(rows.map((row) => _message(row)));
  }

  @override
  Future<List<PluginRevocationOutboxMessage>> claim({
    required String workerId,
    required DateTime now,
    required Duration leaseDuration,
    required int limit,
    required int maxAttempts,
  }) async {
    if (workerId.trim().isEmpty ||
        leaseDuration <= Duration.zero ||
        limit < 1 ||
        maxAttempts < 1) {
      throw ArgumentError('Invalid outbox claim parameters.');
    }
    return _transaction(() {
      final instant = now.toUtc();
      final nowText = _date(instant);
      _db.execute('''
        UPDATE plugin_revocation_outbox
        SET state = 'deadLetter', lease_owner = NULL, lease_token = NULL,
            lease_until = NULL, last_error_code = 'lease_expired_after_max_attempts'
        WHERE state = 'leased' AND lease_until <= ? AND attempts >= ?
      ''', [nowText, maxAttempts]);

      final rows = _db.select('''
        SELECT * FROM plugin_revocation_outbox
        WHERE attempts < ? AND (
          (state = 'pending' AND next_attempt_at <= ?) OR
          (state = 'leased' AND lease_until <= ?)
        )
        ORDER BY occurred_at ASC, event_id ASC
        LIMIT ?
      ''', [maxAttempts, nowText, nowText, limit]);

      final claimed = <PluginRevocationOutboxMessage>[];
      for (final row in rows) {
        final current = Map<String, Object?>.from(row);
        final eventId = current['event_id']! as String;
        final attempts = (current['attempts']! as int) + 1;
        final token = '$workerId:$eventId:$attempts:${instant.microsecondsSinceEpoch}:${_random.nextInt(1 << 32)}';
        final leaseUntil = instant.add(leaseDuration);
        _db.execute('''
          UPDATE plugin_revocation_outbox
          SET state = 'leased', attempts = ?, lease_owner = ?,
              lease_token = ?, lease_until = ?
          WHERE event_id = ?
        ''', [attempts, workerId, token, _date(leaseUntil), eventId]);
        current
          ..['state'] = 'leased'
          ..['attempts'] = attempts
          ..['lease_owner'] = workerId
          ..['lease_token'] = token
          ..['lease_until'] = _date(leaseUntil);
        claimed.add(_message(current));
      }
      return List.unmodifiable(claimed);
    });
  }

  @override
  Future<bool> markDelivered({
    required String eventId,
    required String leaseToken,
    required DateTime deliveredAt,
  }) async =>
      _transaction(() {
        _db.execute('''
          UPDATE plugin_revocation_outbox
          SET state = 'delivered', delivered_at = ?, lease_owner = NULL,
              lease_token = NULL, lease_until = NULL, last_error_code = NULL
          WHERE event_id = ? AND state = 'leased' AND lease_token = ?
        ''', [_date(deliveredAt), eventId, leaseToken]);
        return (_db.select('SELECT changes() AS count').first['count'] as int) == 1;
      });

  @override
  Future<bool> reschedule({
    required String eventId,
    required String leaseToken,
    required DateTime nextAttemptAt,
    required String errorCode,
    required int maxAttempts,
  }) async =>
      _transaction(() {
        _db.execute('''
          UPDATE plugin_revocation_outbox
          SET state = CASE WHEN attempts >= ? THEN 'deadLetter' ELSE 'pending' END,
              next_attempt_at = ?, lease_owner = NULL, lease_token = NULL,
              lease_until = NULL, last_error_code = ?
          WHERE event_id = ? AND state = 'leased' AND lease_token = ?
        ''', [
          maxAttempts,
          _date(nextAttemptAt),
          errorCode,
          eventId,
          leaseToken,
        ]);
        return (_db.select('SELECT changes() AS count').first['count'] as int) == 1;
      });

  Future<PluginRevocationJournalEntry?> readJournal(String idempotencyKey) async {
    _assertOpen();
    final rows = _db.select(
      'SELECT * FROM plugin_revocation_journal WHERE idempotency_key = ?',
      [idempotencyKey],
    );
    return rows.isEmpty ? null : _journal(rows.first);
  }

  Future<List<PluginRevocationJournalEntry>> readAllJournal() async {
    _assertOpen();
    return List.unmodifiable(_db.select(
      'SELECT * FROM plugin_revocation_journal ORDER BY created_at, idempotency_key',
    ).map(_journal));
  }

  static PluginRevocationJournalStatus _journalStatus(
    PluginRevocationExecutionStatus status,
  ) =>
      switch (status) {
        PluginRevocationExecutionStatus.completed ||
        PluginRevocationExecutionStatus.alreadyCompleted ||
        PluginRevocationExecutionStatus.noOp =>
          PluginRevocationJournalStatus.completed,
        PluginRevocationExecutionStatus.rejected =>
          PluginRevocationJournalStatus.rejected,
        PluginRevocationExecutionStatus.unsupported =>
          PluginRevocationJournalStatus.unsupported,
        PluginRevocationExecutionStatus.failed =>
          PluginRevocationJournalStatus.failed,
        PluginRevocationExecutionStatus.requiresReconciliation =>
          PluginRevocationJournalStatus.manualReview,
      };

  static PluginRevocationJournalEntry _journal(Map<String, Object?> row) =>
      PluginRevocationJournalEntry(
        schemaVersion: row['schema_version']! as int,
        idempotencyKey: row['idempotency_key']! as String,
        operationId: row['operation_id']! as String,
        pluginId: row['plugin_id']! as String,
        providerOwnerId: row['provider_owner_id']! as String,
        action: CapabilityImpactAction.values.byName(row['action']! as String),
        status: PluginRevocationJournalStatus.values
            .byName(row['status']! as String),
        revision: row['revision']! as int,
        createdAt: _parseDate(row['created_at']),
        updatedAt: _parseDate(row['updated_at']),
        correlationId: row['correlation_id'] as String?,
        detail: row['detail'] as String?,
      );

  static List<Object?> _journalValues(PluginRevocationJournalEntry entry) => [
        entry.idempotencyKey,
        entry.schemaVersion,
        entry.operationId,
        entry.pluginId,
        entry.providerOwnerId,
        entry.action.name,
        entry.status.name,
        entry.revision,
        _date(entry.createdAt),
        _date(entry.updatedAt),
        entry.correlationId,
        entry.detail,
      ];

  Future<bool> insertJournalIfAbsent(PluginRevocationJournalEntry entry) async =>
      _transaction(() {
        _db.execute('''
          INSERT OR IGNORE INTO plugin_revocation_journal
          (idempotency_key, schema_version, operation_id, plugin_id,
           provider_owner_id, action, status, revision, created_at, updated_at,
           correlation_id, detail)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', _journalValues(entry));
        return (_db.select('SELECT changes() AS count').first['count'] as int) == 1;
      });

  Future<bool> compareAndSetJournal({
    required String idempotencyKey,
    required int expectedRevision,
    required PluginRevocationJournalEntry replacement,
  }) async =>
      _transaction(() {
        if (replacement.idempotencyKey != idempotencyKey ||
            replacement.revision != expectedRevision + 1) {
          throw ArgumentError('Replacement must retain the key and increment revision once.');
        }
        final values = _journalValues(replacement);
        _db.execute('''
          UPDATE plugin_revocation_journal
          SET schema_version = ?, operation_id = ?, plugin_id = ?,
              provider_owner_id = ?, action = ?, status = ?, revision = ?,
              created_at = ?, updated_at = ?, correlation_id = ?, detail = ?
          WHERE idempotency_key = ? AND revision = ?
        ''', [
          ...values.skip(1),
          idempotencyKey,
          expectedRevision,
        ]);
        return (_db.select('SELECT changes() AS count').first['count'] as int) == 1;
      });
}


/// Journal contract adapter. Kept separate because the journal and execution
/// contracts both define a read(key) method with different result types.
final class _SqlitePluginRevocationJournalStore
    implements PluginRevocationJournalStore {
  final SqlitePluginRevocationStore _store;
  _SqlitePluginRevocationJournalStore(this._store);

  @override
  Future<PluginRevocationJournalEntry?> read(String idempotencyKey) =>
      _store.readJournal(idempotencyKey);

  @override
  Future<List<PluginRevocationJournalEntry>> readAll() =>
      _store.readAllJournal();

  @override
  Future<bool> insertIfAbsent(PluginRevocationJournalEntry entry) =>
      _store.insertJournalIfAbsent(entry);

  @override
  Future<bool> compareAndSet({
    required String idempotencyKey,
    required int expectedRevision,
    required PluginRevocationJournalEntry replacement,
  }) =>
      _store.compareAndSetJournal(
        idempotencyKey: idempotencyKey,
        expectedRevision: expectedRevision,
        replacement: replacement,
      );
}
