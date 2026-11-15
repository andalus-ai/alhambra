import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

/// Single-process JSONL audit store for lifecycle storage maintenance.
///
/// Every accepted append is newline-terminated and flushed before completion.
/// Concurrent calls on this instance are serialized. Multiple processes must
/// coordinate externally; this adapter does not claim cross-process locking.
final class JsonlCompositionLifecycleStorageMaintenanceAuditStore
    implements CompositionLifecycleStorageMaintenanceAuditStore {
  final File file;
  final CompositionLifecycleStorageMaintenanceAuditJsonCodec codec;
  Future<void> _writeTail = Future<void>.value();

  JsonlCompositionLifecycleStorageMaintenanceAuditStore({
    required this.file,
    CompositionLifecycleStorageMaintenanceAuditJsonCodec? codec,
  }) : codec = codec ?? const CompositionLifecycleStorageMaintenanceAuditJsonCodec();

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final operation = _writeTail.then((_) => action());
    _writeTail = operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }

  @override
  Future<void> append(
    CompositionLifecycleStorageMaintenanceOperationRecord record,
  ) =>
      _enqueue(() async {
        await file.parent.create(recursive: true);
        await _discardIncompleteTail();
        final records = await _readAll();
        for (final existing in records) {
          if (existing.operationId != record.operationId) continue;
          if (existing.status == record.status) {
            if (codec.encode(existing) == codec.encode(record)) return;
            throw CompositionLifecycleStorageMaintenanceAuditIdentityConflictException(
              operationId: record.operationId,
              status: record.status,
            );
          }
          if (existing.status != CompositionLifecycleStorageMaintenanceOperationStatus.started &&
              record.status != CompositionLifecycleStorageMaintenanceOperationStatus.started) {
            throw CompositionLifecycleStorageMaintenanceAuditIdentityConflictException(
              operationId: record.operationId,
              status: record.status,
            );
          }
        }
        final encoded = utf8.encode(codec.encode(record));
        final handle = await file.open(mode: FileMode.append);
        try {
          await handle.writeFrom(encoded);
          await handle.writeByte(0x0a);
          await handle.flush();
        } finally {
          await handle.close();
        }
      });

  @override
  Future<List<CompositionLifecycleStorageMaintenanceOperationRecord>> query(
    CompositionLifecycleStorageMaintenanceAuditQuery query,
  ) async {
    await _writeTail;
    final records = await _readAll();
    final filtered = records.where((record) {
      if (query.operationId != null && record.operationId != query.operationId) {
        return false;
      }
      if (query.status != null && record.status != query.status) return false;
      if (query.from != null && record.startedAt.isBefore(query.from!)) return false;
      if (query.to != null && record.startedAt.isAfter(query.to!)) return false;
      if (query.after != null && _compare(record, query.after!) <= 0) return false;
      return true;
    }).toList()
      ..sort(_compareRecords);
    return List.unmodifiable(filtered.take(query.limit));
  }

  Future<List<CompositionLifecycleStorageMaintenanceOperationRecord>> _readAll() async {
    if (!await file.exists()) return const [];
    final bytes = await file.readAsBytes();
    final records = <CompositionLifecycleStorageMaintenanceOperationRecord>[];
    var start = 0;
    for (var index = 0; index < bytes.length; index++) {
      if (bytes[index] != 0x0a) continue;
      final line = bytes.sublist(start, index);
      start = index + 1;
      if (line.isEmpty) continue;
      records.add(codec.decode(utf8.decode(line, allowMalformed: false)));
    }
    // An unterminated final line is an interrupted append and is ignored.
    return records;
  }

  Future<void> _discardIncompleteTail() async {
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.last == 0x0a) return;
    final lastNewline = bytes.lastIndexOf(0x0a);
    await file.writeAsBytes(
      bytes.sublist(0, lastNewline + 1),
      mode: FileMode.write,
      flush: true,
    );
  }

  int _compareRecords(
    CompositionLifecycleStorageMaintenanceOperationRecord left,
    CompositionLifecycleStorageMaintenanceOperationRecord right,
  ) {
    final byTime = left.startedAt.compareTo(right.startedAt);
    if (byTime != 0) return byTime;
    final byId = left.operationId.compareTo(right.operationId);
    return byId != 0 ? byId : left.status.name.compareTo(right.status.name);
  }

  int _compare(
    CompositionLifecycleStorageMaintenanceOperationRecord record,
    CompositionLifecycleStorageMaintenanceAuditCursor cursor,
  ) {
    final byTime = record.startedAt.compareTo(cursor.startedAt);
    if (byTime != 0) return byTime;
    final byId = record.operationId.compareTo(cursor.operationId);
    return byId != 0 ? byId : record.status.name.compareTo(cursor.status.name);
  }
}
