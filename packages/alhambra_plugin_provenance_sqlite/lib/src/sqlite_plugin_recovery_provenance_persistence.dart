import 'dart:convert';

import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:sqlite3/sqlite3.dart' as sq;

/// Owns one SQLite database and exposes durable adapters for the three
/// recovery-provenance contracts. A database instance represents one
/// provenance event chain; anchor rows are partitioned by chainId and key
/// lifecycle history is shared by this database.
///
/// Writes use BEGIN IMMEDIATE and perform sequence/head checks inside the
/// transaction. This protects against competing independent connections and
/// processes using the same SQLite database file.
final class SqlitePluginRecoveryProvenancePersistence {
  final sq.Database _database;
  bool _closed = false;

  late final PluginRecoveryProvenanceStore provenanceStore =
      _SqliteProvenanceStore(this);
  late final PluginRecoveryProvenanceAnchorStore anchorStore =
      _SqliteAnchorStore(this);
  late final PluginRecoverySigningKeyHistoryStore keyHistoryStore =
      _SqliteKeyHistoryStore(this);

  SqlitePluginRecoveryProvenancePersistence(String path)
      : _database = sq.sqlite3.open(path) {
    _configure(path);
    _migrate();
  }

  SqlitePluginRecoveryProvenancePersistence.memory()
      : _database = sq.sqlite3.openInMemory() {
    _configure(':memory:');
    _migrate();
  }

  void _configure(String path) {
    _database.execute('PRAGMA busy_timeout = 5000');
    _database.execute('PRAGMA foreign_keys = ON');
    _database.execute('PRAGMA synchronous = FULL');
    if (path != ':memory:') _database.execute('PRAGMA journal_mode = WAL');
  }

  void close() {
    if (_closed) return;
    _database.dispose();
    _closed = true;
  }

  void _assertOpen() {
    if (_closed) throw StateError('SQLite provenance persistence is closed.');
  }

  T _transaction<T>(T Function() operation) {
    _assertOpen();
    _database.execute('BEGIN IMMEDIATE');
    try {
      final result = operation();
      _database.execute('COMMIT');
      return result;
    } catch (_) {
      _database.execute('ROLLBACK');
      rethrow;
    }
  }

  void _migrate() {
    _assertOpen();
    final version =
        _database.select('PRAGMA user_version').first['user_version'] as int;
    if (version > 1) {
      throw UnsupportedError(
        'Provenance database schema version $version is newer than supported version 1.',
      );
    }
    if (version == 1) return;
    _transaction(() {
      _database.execute('''
        CREATE TABLE IF NOT EXISTS alhambra_recovery_provenance_event (
          sequence INTEGER PRIMARY KEY CHECK (sequence >= 1),
          event_id TEXT NOT NULL UNIQUE,
          event_digest TEXT NOT NULL,
          event_json TEXT NOT NULL
        )
      ''');
      _database.execute('''
        CREATE TABLE IF NOT EXISTS alhambra_recovery_provenance_anchor (
          chain_id TEXT NOT NULL,
          anchor_sequence INTEGER NOT NULL CHECK (anchor_sequence >= 1),
          provenance_sequence INTEGER NOT NULL CHECK (provenance_sequence >= 1),
          anchor_json TEXT NOT NULL,
          PRIMARY KEY (chain_id, anchor_sequence),
          UNIQUE (chain_id, provenance_sequence)
        )
      ''');
      _database.execute('''
        CREATE TABLE IF NOT EXISTS alhambra_recovery_signing_key_event (
          sequence INTEGER PRIMARY KEY CHECK (sequence >= 1),
          event_id TEXT NOT NULL UNIQUE,
          key_id TEXT NOT NULL,
          occurred_at TEXT NOT NULL,
          event_json TEXT NOT NULL
        )
      ''');
      _database.execute('''
        CREATE INDEX IF NOT EXISTS idx_alhambra_recovery_key_history
        ON alhambra_recovery_signing_key_event(key_id, sequence)
      ''');
      _database.execute('PRAGMA user_version = 1');
    });
  }

  List<PluginRecoveryProvenanceEvent> _readProvenanceEvents() {
    _assertOpen();
    return _database.select('''
      SELECT event_json FROM alhambra_recovery_provenance_event
      ORDER BY sequence ASC
    ''').map((row) => _decodeProvenance(row['event_json']! as String))
        .toList(growable: false);
  }

  bool _appendProvenance({
    required int expectedSequence,
    required String? expectedHeadDigest,
    required PluginRecoveryProvenanceEvent event,
  }) => _transaction(() {
    final row = _database.select('''
      SELECT sequence, event_digest FROM alhambra_recovery_provenance_event
      ORDER BY sequence DESC LIMIT 1
    ''');
    final actualSequence = row.isEmpty ? 0 : row.first['sequence']! as int;
    final actualDigest = row.isEmpty ? null : row.first['event_digest'] as String?;
    if (actualSequence != expectedSequence ||
        actualDigest != expectedHeadDigest ||
        event.sequence != expectedSequence + 1 ||
        event.previousEventDigest != expectedHeadDigest ||
        _database.select(
          'SELECT 1 FROM alhambra_recovery_provenance_event WHERE event_id = ?',
          [event.eventId],
        ).isNotEmpty) {
      return false;
    }
    _database.execute('''
      INSERT INTO alhambra_recovery_provenance_event
        (sequence, event_id, event_digest, event_json)
      VALUES (?, ?, ?, ?)
    ''', [
      event.sequence,
      event.eventId,
      event.eventDigest,
      _encodeProvenance(event),
    ]);
    return true;
  });

  List<PluginRecoveryProvenanceAnchor> _readAnchors(String chainId) {
    _assertOpen();
    return _database.select('''
      SELECT anchor_json FROM alhambra_recovery_provenance_anchor
      WHERE chain_id = ? ORDER BY anchor_sequence ASC
    ''', [chainId]).map((row) => _decodeAnchor(row['anchor_json']! as String))
        .toList(growable: false);
  }

  bool _appendAnchor({
    required String chainId,
    required int expectedAnchorSequence,
    required PluginRecoveryProvenanceAnchor anchor,
  }) => _transaction(() {
    final row = _database.select('''
      SELECT anchor_sequence FROM alhambra_recovery_provenance_anchor
      WHERE chain_id = ? ORDER BY anchor_sequence DESC LIMIT 1
    ''', [chainId]);
    final actualSequence =
        row.isEmpty ? 0 : row.first['anchor_sequence']! as int;
    final previousProvenanceSequence = row.isEmpty
        ? 0
        : (_database.select(
            'SELECT provenance_sequence FROM alhambra_recovery_provenance_anchor WHERE chain_id = ? ORDER BY anchor_sequence DESC LIMIT 1',
            [chainId],
          ).first['provenance_sequence']! as int);
    if (anchor.chainId != chainId ||
        actualSequence != expectedAnchorSequence ||
        anchor.anchorSequence != expectedAnchorSequence + 1 ||
        anchor.provenanceSequence <= previousProvenanceSequence) {
      return false;
    }
    _database.execute('''
      INSERT INTO alhambra_recovery_provenance_anchor
        (chain_id, anchor_sequence, provenance_sequence, anchor_json)
      VALUES (?, ?, ?, ?)
    ''', [
      chainId,
      anchor.anchorSequence,
      anchor.provenanceSequence,
      _encodeAnchor(anchor),
    ]);
    return true;
  });

  List<PluginRecoverySigningKeyLifecycleEvent> _readKeyEvents() {
    _assertOpen();
    return _database.select('''
      SELECT event_json FROM alhambra_recovery_signing_key_event
      ORDER BY sequence ASC
    ''').map((row) => _decodeKeyEvent(row['event_json']! as String))
        .toList(growable: false);
  }

  bool _appendKeyEvent({
    required int expectedSequence,
    required PluginRecoverySigningKeyLifecycleEvent event,
  }) => _transaction(() {
    final row = _database.select('''
      SELECT sequence FROM alhambra_recovery_signing_key_event
      ORDER BY sequence DESC LIMIT 1
    ''');
    final actualSequence = row.isEmpty ? 0 : row.first['sequence']! as int;
    if (actualSequence != expectedSequence ||
        event.sequence != expectedSequence + 1 ||
        _database.select(
          'SELECT 1 FROM alhambra_recovery_signing_key_event WHERE event_id = ?',
          [event.eventId],
        ).isNotEmpty) {
      return false;
    }
    _database.execute('''
      INSERT INTO alhambra_recovery_signing_key_event
        (sequence, event_id, key_id, occurred_at, event_json)
      VALUES (?, ?, ?, ?, ?)
    ''', [
      event.sequence,
      event.eventId,
      event.keyId,
      event.occurredAt.toUtc().toIso8601String(),
      _encodeKeyEvent(event),
    ]);
    return true;
  });

  static String _encodeProvenance(PluginRecoveryProvenanceEvent event) =>
      jsonEncode({
        'schemaVersion': event.schemaVersion,
        'eventId': event.eventId,
        'sequence': event.sequence,
        'action': event.action.name,
        'occurredAt': event.occurredAt.toUtc().toIso8601String(),
        'sourceDeploymentId': event.sourceDeploymentId,
        'actorId': event.actorId,
        'packageId': event.packageId,
        'packageDigestAlgorithm': event.packageDigestAlgorithm,
        'packageDigest': event.packageDigest,
        'signerKeyId': event.signerKeyId,
        'signatureAlgorithm': event.signatureAlgorithm,
        'signature': event.signature,
        'previousEventDigest': event.previousEventDigest,
        'eventDigestAlgorithm': event.eventDigestAlgorithm,
        'eventDigest': event.eventDigest,
      });

  static PluginRecoveryProvenanceEvent _decodeProvenance(String json) {
    final value = jsonDecode(json) as Map<String, dynamic>;
    return PluginRecoveryProvenanceEvent(
      schemaVersion: value['schemaVersion'] as int,
      eventId: value['eventId'] as String,
      sequence: value['sequence'] as int,
      action: PluginRecoveryProvenanceAction.values.byName(value['action'] as String),
      occurredAt: DateTime.parse(value['occurredAt'] as String),
      sourceDeploymentId: value['sourceDeploymentId'] as String,
      actorId: value['actorId'] as String?,
      packageId: value['packageId'] as String,
      packageDigestAlgorithm: value['packageDigestAlgorithm'] as String,
      packageDigest: value['packageDigest'] as String,
      signerKeyId: value['signerKeyId'] as String?,
      signatureAlgorithm: value['signatureAlgorithm'] as String?,
      signature: value['signature'] as String?,
      previousEventDigest: value['previousEventDigest'] as String?,
      eventDigestAlgorithm: value['eventDigestAlgorithm'] as String,
      eventDigest: value['eventDigest'] as String,
    );
  }

  static String _encodeAnchor(PluginRecoveryProvenanceAnchor anchor) =>
      jsonEncode({
        'chainId': anchor.chainId,
        'anchorSequence': anchor.anchorSequence,
        'provenanceSequence': anchor.provenanceSequence,
        'headEventDigestAlgorithm': anchor.headEventDigestAlgorithm,
        'headEventDigest': anchor.headEventDigest,
        'anchoredAt': anchor.anchoredAt.toUtc().toIso8601String(),
        'signerKeyId': anchor.signerKeyId,
        'signatureAlgorithm': anchor.signatureAlgorithm,
        'signature': anchor.signature,
      });

  static PluginRecoveryProvenanceAnchor _decodeAnchor(String json) {
    final value = jsonDecode(json) as Map<String, dynamic>;
    return PluginRecoveryProvenanceAnchor(
      chainId: value['chainId'] as String,
      anchorSequence: value['anchorSequence'] as int,
      provenanceSequence: value['provenanceSequence'] as int,
      headEventDigestAlgorithm: value['headEventDigestAlgorithm'] as String,
      headEventDigest: value['headEventDigest'] as String,
      anchoredAt: DateTime.parse(value['anchoredAt'] as String),
      signerKeyId: value['signerKeyId'] as String,
      signatureAlgorithm: value['signatureAlgorithm'] as String,
      signature: value['signature'] as String,
    );
  }

  static String _encodeKeyEvent(
    PluginRecoverySigningKeyLifecycleEvent event,
  ) => jsonEncode({
    'eventId': event.eventId,
    'sequence': event.sequence,
    'keyId': event.keyId,
    'algorithm': event.algorithm,
    'principalId': event.principalId,
    'action': event.action.name,
    'occurredAt': event.occurredAt.toUtc().toIso8601String(),
    'validFrom': event.validFrom?.toUtc().toIso8601String(),
    'validUntil': event.validUntil?.toUtc().toIso8601String(),
    'successorKeyId': event.successorKeyId,
    'reasonCode': event.reasonCode,
  });

  static PluginRecoverySigningKeyLifecycleEvent _decodeKeyEvent(String json) {
    final value = jsonDecode(json) as Map<String, dynamic>;
    return PluginRecoverySigningKeyLifecycleEvent(
      eventId: value['eventId'] as String,
      sequence: value['sequence'] as int,
      keyId: value['keyId'] as String,
      algorithm: value['algorithm'] as String,
      principalId: value['principalId'] as String,
      action: PluginRecoverySigningKeyLifecycleAction.values.byName(
        value['action'] as String,
      ),
      occurredAt: DateTime.parse(value['occurredAt'] as String),
      validFrom: value['validFrom'] == null
          ? null
          : DateTime.parse(value['validFrom'] as String),
      validUntil: value['validUntil'] == null
          ? null
          : DateTime.parse(value['validUntil'] as String),
      successorKeyId: value['successorKeyId'] as String?,
      reasonCode: value['reasonCode'] as String?,
    );
  }
}

final class _SqliteProvenanceStore implements PluginRecoveryProvenanceStore {
  final SqlitePluginRecoveryProvenancePersistence owner;
  const _SqliteProvenanceStore(this.owner);

  @override
  Future<List<PluginRecoveryProvenanceEvent>> readAll() async =>
      owner._readProvenanceEvents();

  @override
  Future<bool> appendIfHeadMatches({
    required int expectedSequence,
    required String? expectedHeadDigest,
    required PluginRecoveryProvenanceEvent event,
  }) async => owner._appendProvenance(
    expectedSequence: expectedSequence,
    expectedHeadDigest: expectedHeadDigest,
    event: event,
  );
}

final class _SqliteAnchorStore implements PluginRecoveryProvenanceAnchorStore {
  final SqlitePluginRecoveryProvenancePersistence owner;
  const _SqliteAnchorStore(this.owner);

  @override
  Future<List<PluginRecoveryProvenanceAnchor>> readAll(String chainId) async =>
      owner._readAnchors(chainId);

  @override
  Future<bool> appendIfSequenceMatches({
    required String chainId,
    required int expectedAnchorSequence,
    required PluginRecoveryProvenanceAnchor anchor,
  }) async => owner._appendAnchor(
    chainId: chainId,
    expectedAnchorSequence: expectedAnchorSequence,
    anchor: anchor,
  );
}

final class _SqliteKeyHistoryStore
    implements PluginRecoverySigningKeyHistoryStore {
  final SqlitePluginRecoveryProvenancePersistence owner;
  const _SqliteKeyHistoryStore(this.owner);

  @override
  Future<List<PluginRecoverySigningKeyLifecycleEvent>> readAll() async =>
      owner._readKeyEvents();

  @override
  Future<bool> appendIfSequenceMatches({
    required int expectedSequence,
    required PluginRecoverySigningKeyLifecycleEvent event,
  }) async => owner._appendKeyEvent(
    expectedSequence: expectedSequence,
    event: event,
  );
}
