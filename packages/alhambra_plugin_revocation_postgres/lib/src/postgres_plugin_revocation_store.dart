import 'dart:math';

import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:postgres/postgres.dart';

/// PostgreSQL-backed revocation execution store, journal and outbox.
///
/// The pool is shared safely across callers. Every state-changing operation
/// runs in a database transaction. Outbox claims use SKIP LOCKED so separate
/// workers do not claim the same row.
final class PostgresPluginRevocationStore
    implements
        TransactionalPluginRevocationStore,
        PluginRevocationOutboxStore,
        PluginRevocationOutboxInspectionStore,
        PluginRevocationDeadLetterReplayStore,
        PluginRevocationOperatorActionInspectionStore {
  final Pool<dynamic> _pool;
  final Random _random;
  bool _closed = false;

  PostgresPluginRevocationStore(
    this._pool, {
    Random? random,
  }) : _random = random ?? Random.secure();

  /// Creates a pooled adapter from a PostgreSQL connection URL.
  ///
  /// Configure TLS, credentials, timeouts and max_connection_count in [url].
  factory PostgresPluginRevocationStore.fromUrl(
    String url, {
    Random? random,
  }) =>
      PostgresPluginRevocationStore(Pool.withUrl(url), random: random);

  /// Journal contract view backed by the same PostgreSQL pool.
  PluginRevocationJournalStore get journalStore =>
      _PostgresPluginRevocationJournalStore(this);

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _pool.close();
  }

  void _assertOpen() {
    if (_closed) throw StateError('PostgreSQL revocation store is closed.');
  }

  /// Applies schema version 1. DDL is transactional and safe to run at startup.
  ///
  /// Production deployments should run this with a migration role and give the
  /// application role only the required DML permissions.
  Future<void> migrate() async {
    _assertOpen();
    await _pool.runTx((tx) async {
      await tx.execute('''
        CREATE TABLE IF NOT EXISTS alhambra_plugin_revocation_schema (
          version INTEGER PRIMARY KEY,
          applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )
      ''');
      final schema = await tx.execute(
        'SELECT COALESCE(MAX(version), 0) AS version FROM alhambra_plugin_revocation_schema',
      );
      final currentVersion = schema.first.toColumnMap()['version'] as int;
      if (currentVersion > 2) {
        throw UnsupportedError('Database schema version $currentVersion is newer than this adapter supports.');
      }
      await tx.execute('''
        CREATE TABLE IF NOT EXISTS alhambra_plugin_revocation_execution (
          idempotency_key TEXT PRIMARY KEY,
          operation_id TEXT NOT NULL,
          plugin_id TEXT NOT NULL,
          provider_owner_id TEXT NOT NULL,
          action TEXT NOT NULL,
          status TEXT NOT NULL,
          updated_at TIMESTAMPTZ NOT NULL,
          detail TEXT
        )
      ''');
      await tx.execute('''
        CREATE TABLE IF NOT EXISTS alhambra_plugin_revocation_journal (
          idempotency_key TEXT PRIMARY KEY,
          schema_version INTEGER NOT NULL CHECK (schema_version >= 1),
          operation_id TEXT NOT NULL,
          plugin_id TEXT NOT NULL,
          provider_owner_id TEXT NOT NULL,
          action TEXT NOT NULL,
          status TEXT NOT NULL,
          revision BIGINT NOT NULL CHECK (revision >= 1),
          created_at TIMESTAMPTZ NOT NULL,
          updated_at TIMESTAMPTZ NOT NULL,
          correlation_id TEXT,
          detail TEXT
        )
      ''');
      await tx.execute('''
        CREATE TABLE IF NOT EXISTS alhambra_plugin_revocation_outbox (
          event_id TEXT PRIMARY KEY,
          idempotency_key TEXT NOT NULL UNIQUE,
          operation_id TEXT NOT NULL,
          plugin_id TEXT NOT NULL,
          provider_owner_id TEXT NOT NULL,
          action TEXT NOT NULL,
          outcome TEXT NOT NULL,
          occurred_at TIMESTAMPTZ NOT NULL,
          detail TEXT,
          state TEXT NOT NULL CHECK (state IN ('pending', 'leased', 'delivered', 'deadLetter')),
          attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
          next_attempt_at TIMESTAMPTZ NOT NULL,
          lease_owner TEXT,
          lease_token TEXT,
          lease_until TIMESTAMPTZ,
          delivered_at TIMESTAMPTZ,
          last_error_code TEXT
        )
      ''');
      await tx.execute('''
        CREATE INDEX IF NOT EXISTS idx_alhambra_revocation_outbox_due
        ON alhambra_plugin_revocation_outbox (next_attempt_at, occurred_at, event_id)
        WHERE state = 'pending'
      ''');
      await tx.execute('''
        CREATE INDEX IF NOT EXISTS idx_alhambra_revocation_outbox_expired_lease
        ON alhambra_plugin_revocation_outbox (lease_until, occurred_at, event_id)
        WHERE state = 'leased'
      ''');
      await tx.execute('''
        INSERT INTO alhambra_plugin_revocation_schema (version)
        VALUES (1) ON CONFLICT (version) DO NOTHING
      ''');
      if (currentVersion < 2) {
        await tx.execute('ALTER TABLE alhambra_plugin_revocation_outbox ADD COLUMN IF NOT EXISTS replay_of_event_id TEXT');
        await tx.execute('ALTER TABLE alhambra_plugin_revocation_outbox ADD COLUMN IF NOT EXISTS replay_generation INTEGER NOT NULL DEFAULT 0');
        await tx.execute('''CREATE UNIQUE INDEX IF NOT EXISTS idx_alhambra_revocation_replay_generation ON alhambra_plugin_revocation_outbox(replay_of_event_id, replay_generation) WHERE replay_generation > 0''');
        await tx.execute('''CREATE TABLE IF NOT EXISTS alhambra_plugin_revocation_operator_action (action_id TEXT PRIMARY KEY, actor_id TEXT NOT NULL, reason TEXT NOT NULL, approval_reference TEXT NOT NULL, target_event_id TEXT NOT NULL REFERENCES alhambra_plugin_revocation_outbox(event_id), replay_event_id TEXT NOT NULL UNIQUE REFERENCES alhambra_plugin_revocation_outbox(event_id), replay_generation INTEGER NOT NULL CHECK (replay_generation >= 1), occurred_at TIMESTAMPTZ NOT NULL)''');
        await tx.execute('CREATE INDEX IF NOT EXISTS idx_alhambra_revocation_operator_target ON alhambra_plugin_revocation_operator_action(target_event_id, replay_generation)');
        await tx.execute('INSERT INTO alhambra_plugin_revocation_schema (version) VALUES (2) ON CONFLICT (version) DO NOTHING');
      }
      if (currentVersion < 3) {
        await tx.execute(
          "ALTER TABLE alhambra_plugin_revocation_operator_action "
          "ADD COLUMN IF NOT EXISTS scope_id TEXT NOT NULL DEFAULT 'default'",
        );
        await tx.execute(
          'INSERT INTO alhambra_plugin_revocation_schema (version) '
          'VALUES (3) ON CONFLICT (version) DO NOTHING',
        );
      }
    });
  }

  static DateTime _date(Object? value) =>
      (value as DateTime).toUtc();

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
        updatedAt: _date(row['updated_at']),
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
        occurredAt: _date(row['occurred_at']),
        detail: row['detail'] as String?,
        replayOfEventId: row['replay_of_event_id'] as String?,
        replayGeneration: row['replay_generation'] as int? ?? 0,
      );

  static PluginRevocationOutboxMessage _message(
    Map<String, Object?> row,
  ) =>
      PluginRevocationOutboxMessage(
        event: _event(row),
        state: PluginRevocationOutboxState.values
            .byName(row['state']! as String),
        attempts: row['attempts']! as int,
        nextAttemptAt: _date(row['next_attempt_at']),
        leaseOwner: row['lease_owner'] as String?,
        leaseToken: row['lease_token'] as String?,
        leaseUntil: row['lease_until'] == null
            ? null
            : _date(row['lease_until']),
        deliveredAt: row['delivered_at'] == null
            ? null
            : _date(row['delivered_at']),
        lastErrorCode: row['last_error_code'] as String?,
      );

  static PluginRevocationJournalEntry _journal(
    Map<String, Object?> row,
  ) =>
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
        createdAt: _date(row['created_at']),
        updatedAt: _date(row['updated_at']),
        correlationId: row['correlation_id'] as String?,
        detail: row['detail'] as String?,
      );

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

  @override
  Future<PluginRevocationExecutionRecord?> read(String idempotencyKey) async {
    _assertOpen();
    final rows = await _pool.execute(
      r'SELECT * FROM alhambra_plugin_revocation_execution WHERE idempotency_key = $1',
      parameters: [idempotencyKey],
    );
    return rows.isEmpty ? null : _execution(rows.first.toColumnMap());
  }

  @override
  Future<bool> writePending(PluginRevocationExecutionRecord record) async {
    _assertOpen();
    return _pool.runTx((tx) async {
      final inserted = await tx.execute(
        r'''
          INSERT INTO alhambra_plugin_revocation_execution
            (idempotency_key, operation_id, plugin_id, provider_owner_id,
             action, status, updated_at, detail)
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
          ON CONFLICT (idempotency_key) DO NOTHING
          RETURNING idempotency_key
        ''',
        parameters: [
          record.idempotencyKey,
          record.operationId,
          record.pluginId,
          record.providerOwnerId,
          record.action.name,
          record.status.name,
          record.updatedAt.toUtc(),
          record.detail,
        ],
      );
      if (inserted.isEmpty) return false;

      await tx.execute(
        r'''
          INSERT INTO alhambra_plugin_revocation_journal
            (idempotency_key, schema_version, operation_id, plugin_id,
             provider_owner_id, action, status, revision, created_at,
             updated_at, detail)
          VALUES ($1, $2, $3, $4, $5, $6, 'pending', 1, $7, $7, $8)
        ''',
        parameters: [
          record.idempotencyKey,
          PluginRevocationJournalEntry.currentSchemaVersion,
          record.operationId,
          record.pluginId,
          record.providerOwnerId,
          record.action.name,
          record.updatedAt.toUtc(),
          record.detail,
        ],
      );
      return true;
    });
  }

  @override
  Future<void> complete(PluginRevocationExecutionRecord record) =>
      completeAndEnqueue(record);

  @override
  Future<void> append(PluginRevocationExecutionRecord record) async {
    _assertOpen();
    await _pool.runTx((tx) => _enqueue(tx, record));
  }

  Future<void> _enqueue(TxSession tx, PluginRevocationExecutionRecord record) async {
    await tx.execute(
      r'''
        INSERT INTO alhambra_plugin_revocation_outbox
          (event_id, idempotency_key, operation_id, plugin_id, provider_owner_id,
           action, outcome, occurred_at, detail, state, attempts, next_attempt_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'pending', 0, $8)
        ON CONFLICT (idempotency_key) DO NOTHING
      ''',
      parameters: [
        '${record.idempotencyKey}:terminal',
        record.idempotencyKey,
        record.operationId,
        record.pluginId,
        record.providerOwnerId,
        record.action.name,
        record.status.name,
        record.updatedAt.toUtc(),
        record.detail,
      ],
    );
  }

  @override
  Future<void> completeAndEnqueue(
    PluginRevocationExecutionRecord record,
  ) async {
    _assertOpen();
    await _pool.runTx((tx) async {
      final execution = await tx.execute(
        r'''
          UPDATE alhambra_plugin_revocation_execution
          SET operation_id = $1, plugin_id = $2, provider_owner_id = $3,
              action = $4, status = $5, updated_at = $6, detail = $7
          WHERE idempotency_key = $8
          RETURNING idempotency_key
        ''',
        parameters: [
          record.operationId,
          record.pluginId,
          record.providerOwnerId,
          record.action.name,
          record.status.name,
          record.updatedAt.toUtc(),
          record.detail,
          record.idempotencyKey,
        ],
      );
      if (execution.isEmpty) {
        throw StateError('Cannot complete an unclaimed revocation operation.');
      }

      final journal = await tx.execute(
        r'''
          UPDATE alhambra_plugin_revocation_journal
          SET status = $1, revision = revision + 1, updated_at = $2, detail = $3
          WHERE idempotency_key = $4
          RETURNING idempotency_key
        ''',
        parameters: [
          _journalStatus(record.status).name,
          record.updatedAt.toUtc(),
          record.detail,
          record.idempotencyKey,
        ],
      );
      if (journal.isEmpty) {
        throw StateError('Revocation journal row is missing; transaction rolled back.');
      }
      await _enqueue(tx, record);
    });
  }

  @override
  Future<List<PluginRevocationOutboxMessage>> readAllOutbox() async {
    _assertOpen();
    final rows = await _pool.execute(
      'SELECT * FROM alhambra_plugin_revocation_outbox ORDER BY occurred_at, event_id',
    );
    return List.unmodifiable(
      rows.map((row) => _message(row.toColumnMap())),
    );
  }

  @override
  Future<PluginRevocationReplayResult?> replayDeadLetter(
    PluginRevocationReplayRequest request,
  ) async {
    _assertOpen();
    return _pool.runTx((tx) async {
      await tx.execute(
        r'SELECT pg_advisory_xact_lock(hashtextextended($1, 0))',
        parameters: [request.actionId],
      );
      final priorRows = await tx.execute(
        r'SELECT * FROM alhambra_plugin_revocation_operator_action WHERE action_id = $1',
        parameters: [request.actionId],
      );
      if (priorRows.isNotEmpty) {
        final row = priorRows.first.toColumnMap();
        if (row['target_event_id'] != request.targetEventId ||
            row['actor_id'] != request.actorId ||
            row['reason'] != request.reason ||
            row['approval_reference'] != request.approvalReference) {
          throw StateError(
            'Operator action ID was already used with different replay details.',
          );
        }
        final replayRows = await tx.execute(
          r'SELECT * FROM alhambra_plugin_revocation_outbox WHERE event_id = $1',
          parameters: [row['replay_event_id']],
        );
        if (replayRows.isEmpty) {
          throw StateError('Recorded replay event is missing.');
        }
        final audit = PluginRevocationOperatorAction(
          actionId: row['action_id'] as String,
          actorId: row['actor_id'] as String,
          scopeId: row['scope_id'] as String,
          reason: row['reason'] as String,
          approvalReference: row['approval_reference'] as String,
          targetEventId: row['target_event_id'] as String,
          replayEventId: row['replay_event_id'] as String,
          replayGeneration: row['replay_generation'] as int,
          occurredAt: _date(row['occurred_at']),
        );
        return PluginRevocationReplayResult(
          audit,
          _message(replayRows.first.toColumnMap()),
        );
      }
      final sourceRows = await tx.execute(
        r"SELECT * FROM alhambra_plugin_revocation_outbox "
        r"WHERE event_id = $1 AND state = 'deadLetter' FOR UPDATE",
        parameters: [request.targetEventId],
      );
      if (sourceRows.isEmpty) return null;
      final source = sourceRows.first.toColumnMap();
      final generationRows = await tx.execute(
        r'SELECT COALESCE(MAX(replay_generation), 0) AS generation '
        r'FROM alhambra_plugin_revocation_operator_action WHERE target_event_id = $1',
        parameters: [request.targetEventId],
      );
      final generation =
          (generationRows.first.toColumnMap()['generation'] as int) + 1;
      final sourceEventId = source['event_id'] as String;
      final replayEventId = '$sourceEventId:replay:$generation';
      final replayKey = '${source['idempotency_key']}:replay:$generation';
      final at = request.occurredAt.toUtc();
      final inserted = await tx.execute(
        r'''
          INSERT INTO alhambra_plugin_revocation_outbox
          (event_id, idempotency_key, operation_id, plugin_id, provider_owner_id,
           action, outcome, occurred_at, detail, state, attempts, next_attempt_at,
           replay_of_event_id, replay_generation)
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'pending', 0, $8, $10, $11)
          RETURNING *
        ''',
        parameters: [
          replayEventId, replayKey, source['operation_id'], source['plugin_id'],
          source['provider_owner_id'], source['action'], source['outcome'],
          at, source['detail'], sourceEventId, generation,
        ],
      );
      await tx.execute(
        r'''
          INSERT INTO alhambra_plugin_revocation_operator_action
          (action_id, actor_id, scope_id, reason, approval_reference, target_event_id,
           replay_event_id, replay_generation, occurred_at)
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        ''',
        parameters: [
          request.actionId, request.actorId, request.scopeId, request.reason,
          request.approvalReference, sourceEventId, replayEventId, generation, at,
        ],
      );
      final audit = PluginRevocationOperatorAction(
        actionId: request.actionId,
        actorId: request.actorId,
        scopeId: request.scopeId,
        reason: request.reason,
        approvalReference: request.approvalReference,
        targetEventId: sourceEventId,
        replayEventId: replayEventId,
        replayGeneration: generation,
        occurredAt: at,
      );
      return PluginRevocationReplayResult(
        audit,
        _message(inserted.first.toColumnMap()),
      );
    });
  }

  @override
  Future<List<PluginRevocationOperatorAction>> readOperatorActions() async {
    _assertOpen();
    final rows = await _pool.execute(
      'SELECT * FROM alhambra_plugin_revocation_operator_action ORDER BY occurred_at, action_id',
    );
    return List.unmodifiable(rows.map((row) {
      final value = row.toColumnMap();
      return PluginRevocationOperatorAction(
        actionId: value['action_id'] as String,
        actorId: value['actor_id'] as String,
        scopeId: value['scope_id'] as String,
        reason: value['reason'] as String,
        approvalReference: value['approval_reference'] as String,
        targetEventId: value['target_event_id'] as String,
        replayEventId: value['replay_event_id'] as String,
        replayGeneration: value['replay_generation'] as int,
        occurredAt: _date(value['occurred_at']),
      );
    }));
  }

  @override
  Future<List<PluginRevocationOutboxMessage>> claim({
    required String workerId,
    required DateTime now,
    required Duration leaseDuration,
    required int limit,
    required int maxAttempts,
  }) async {
    _assertOpen();
    if (workerId.trim().isEmpty ||
        leaseDuration <= Duration.zero ||
        limit < 1 ||
        maxAttempts < 1) {
      throw ArgumentError('Invalid outbox claim parameters.');
    }
    final instant = now.toUtc();
    return _pool.runTx((tx) async {
      await tx.execute(
        r'''
          UPDATE alhambra_plugin_revocation_outbox
          SET state = 'deadLetter', lease_owner = NULL, lease_token = NULL,
              lease_until = NULL,
              last_error_code = 'lease_expired_after_max_attempts'
          WHERE state = 'leased' AND lease_until <= $1 AND attempts >= $2
        ''',
        parameters: [instant, maxAttempts],
      );

      final rows = await tx.execute(
        r'''
          WITH due AS (
            SELECT event_id
            FROM alhambra_plugin_revocation_outbox
            WHERE attempts < $1 AND (
              (state = 'pending' AND next_attempt_at <= $2) OR
              (state = 'leased' AND lease_until <= $2)
            )
            ORDER BY occurred_at, event_id
            LIMIT $3
            FOR UPDATE SKIP LOCKED
          )
          UPDATE alhambra_plugin_revocation_outbox AS outbox
          SET state = 'leased',
              attempts = outbox.attempts + 1,
              lease_owner = $4,
              lease_token = $5 || ':' || outbox.event_id || ':' ||
                (outbox.attempts + 1)::text || ':' || $6::text,
              lease_until = $7
          FROM due
          WHERE outbox.event_id = due.event_id
          RETURNING outbox.*
        ''',
        parameters: [
          maxAttempts,
          instant,
          limit,
          workerId,
          workerId,
          '${instant.microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}',
          instant.add(leaseDuration),
        ],
      );
      final messages = rows
          .map((row) => _message(row.toColumnMap()))
          .toList(growable: false)
        ..sort((a, b) => a.event.occurredAt.compareTo(b.event.occurredAt));
      return List.unmodifiable(messages);
    });
  }

  @override
  Future<bool> markDelivered({
    required String eventId,
    required String leaseToken,
    required DateTime deliveredAt,
  }) async {
    _assertOpen();
    final result = await _pool.execute(
      r'''
        UPDATE alhambra_plugin_revocation_outbox
        SET state = 'delivered', delivered_at = $1, lease_owner = NULL,
            lease_token = NULL, lease_until = NULL, last_error_code = NULL
        WHERE event_id = $2 AND state = 'leased' AND lease_token = $3
      ''',
      parameters: [deliveredAt.toUtc(), eventId, leaseToken],
    );
    return result.affectedRows == 1;
  }

  @override
  Future<bool> reschedule({
    required String eventId,
    required String leaseToken,
    required DateTime nextAttemptAt,
    required String errorCode,
    required int maxAttempts,
  }) async {
    _assertOpen();
    final result = await _pool.execute(
      r'''
        UPDATE alhambra_plugin_revocation_outbox
        SET state = CASE WHEN attempts >= $1 THEN 'deadLetter' ELSE 'pending' END,
            next_attempt_at = $2, lease_owner = NULL, lease_token = NULL,
            lease_until = NULL, last_error_code = $3
        WHERE event_id = $4 AND state = 'leased' AND lease_token = $5
      ''',
      parameters: [
        maxAttempts,
        nextAttemptAt.toUtc(),
        errorCode,
        eventId,
        leaseToken,
      ],
    );
    return result.affectedRows == 1;
  }

  Future<PluginRevocationJournalEntry?> _readJournal(
    String idempotencyKey,
  ) async {
    _assertOpen();
    final rows = await _pool.execute(
      r'SELECT * FROM alhambra_plugin_revocation_journal WHERE idempotency_key = $1',
      parameters: [idempotencyKey],
    );
    return rows.isEmpty ? null : _journal(rows.first.toColumnMap());
  }

  Future<List<PluginRevocationJournalEntry>> _readAllJournal() async {
    _assertOpen();
    final rows = await _pool.execute(
      'SELECT * FROM alhambra_plugin_revocation_journal ORDER BY created_at, idempotency_key',
    );
    return List.unmodifiable(rows.map((row) => _journal(row.toColumnMap())));
  }

  Future<bool> _insertJournalIfAbsent(
    PluginRevocationJournalEntry entry,
  ) async {
    _assertOpen();
    final rows = await _pool.execute(
      r'''
        INSERT INTO alhambra_plugin_revocation_journal
          (idempotency_key, schema_version, operation_id, plugin_id,
           provider_owner_id, action, status, revision, created_at,
           updated_at, correlation_id, detail)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        ON CONFLICT (idempotency_key) DO NOTHING
        RETURNING idempotency_key
      ''',
      parameters: [
        entry.idempotencyKey,
        entry.schemaVersion,
        entry.operationId,
        entry.pluginId,
        entry.providerOwnerId,
        entry.action.name,
        entry.status.name,
        entry.revision,
        entry.createdAt.toUtc(),
        entry.updatedAt.toUtc(),
        entry.correlationId,
        entry.detail,
      ],
    );
    return rows.isNotEmpty;
  }

  Future<bool> _compareAndSetJournal({
    required String idempotencyKey,
    required int expectedRevision,
    required PluginRevocationJournalEntry replacement,
  }) async {
    _assertOpen();
    if (replacement.idempotencyKey != idempotencyKey ||
        replacement.revision != expectedRevision + 1) {
      throw ArgumentError('Replacement must retain the key and increment revision once.');
    }
    final rows = await _pool.execute(
      r'''
        UPDATE alhambra_plugin_revocation_journal
        SET schema_version = $1, operation_id = $2, plugin_id = $3,
            provider_owner_id = $4, action = $5, status = $6, revision = $7,
            created_at = $8, updated_at = $9, correlation_id = $10, detail = $11
        WHERE idempotency_key = $12 AND revision = $13
        RETURNING idempotency_key
      ''',
      parameters: [
        replacement.schemaVersion,
        replacement.operationId,
        replacement.pluginId,
        replacement.providerOwnerId,
        replacement.action.name,
        replacement.status.name,
        replacement.revision,
        replacement.createdAt.toUtc(),
        replacement.updatedAt.toUtc(),
        replacement.correlationId,
        replacement.detail,
        idempotencyKey,
        expectedRevision,
      ],
    );
    return rows.isNotEmpty;
  }
}

final class _PostgresPluginRevocationJournalStore
    implements PluginRevocationJournalStore {
  final PostgresPluginRevocationStore _store;
  _PostgresPluginRevocationJournalStore(this._store);

  @override
  Future<PluginRevocationJournalEntry?> read(String idempotencyKey) =>
      _store._readJournal(idempotencyKey);

  @override
  Future<List<PluginRevocationJournalEntry>> readAll() =>
      _store._readAllJournal();

  @override
  Future<bool> insertIfAbsent(PluginRevocationJournalEntry entry) =>
      _store._insertJournalIfAbsent(entry);

  @override
  Future<bool> compareAndSet({
    required String idempotencyKey,
    required int expectedRevision,
    required PluginRevocationJournalEntry replacement,
  }) =>
      _store._compareAndSetJournal(
        idempotencyKey: idempotencyKey,
        expectedRevision: expectedRevision,
        replacement: replacement,
      );
}
