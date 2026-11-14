import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

import 'jsonl_sparse_lifecycle_index.dart';

/// Append-only JSON Lines store for composition lifecycle events.
///
/// Each line is a self-contained, versioned event record. Appends are
/// serialized within this store instance and flushed before [append]
/// completes. Compaction uses a sibling temporary directory so the new file
/// is prepared on the same filesystem before the old file is moved aside.
///
/// This implementation is intended for a single-process writer. Multiple
/// processes writing the same file require an external lock or a different
/// storage adapter.
final class JsonlCompositionLifecycleEventStore
    implements CompositionLifecycleEventStore, CompositionLifecycleStorageHealthProvider {
  final File file;
  final CompositionLifecycleEventJsonCodec codec;

  Future<void> _writeTail = Future<void>.value();
  DateTime? _lastSuccessfulWriteAt;
  Object? _lastWriteError;

  late final JsonlSparseLifecycleIndex _sparseIndex =
      JsonlSparseLifecycleIndex(logFile: file, codec: codec);

  JsonlCompositionLifecycleEventStore({
    required this.file,
    CompositionLifecycleEventJsonCodec? codec,
  }) : codec = codec ?? const CompositionLifecycleEventJsonCodec();

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final operation = _writeTail.then((_) => action());
    // Keep the queue usable after failure while preserving the failure for
    // the caller that submitted this operation.
    _writeTail = operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }

  @override
  Future<void> append(CompositionLifecycleEvent event) => _enqueue(() async {
        try {
          await _appendOne(event);
          _lastSuccessfulWriteAt = DateTime.now().toUtc();
          _lastWriteError = null;
        } on Object catch (error) {
          _lastWriteError = error;
          rethrow;
        }
      });

  @override
  Future<CompositionLifecycleStorageHealth> inspectHealth() async {
    await _writeTail;
    try {
      final exists = await file.exists();
      final primaryBytes = exists ? await file.length() : 0;
      final sidecar = File('${file.path}.sparse-index.json');
      final sidecarExists = await sidecar.exists();
      final auxiliaryBytes = sidecarExists ? await sidecar.length() : 0;
      final error = _lastWriteError;
      return CompositionLifecycleStorageHealth(
        state: error == null
            ? CompositionLifecycleStorageHealthState.healthy
            : CompositionLifecycleStorageHealthState.degraded,
        checkedAt: DateTime.now().toUtc(),
        lastSuccessfulWriteAt: _lastSuccessfulWriteAt,
        lastError: error?.toString(),
        primaryStorageBytes: primaryBytes,
        auxiliaryStorageBytes: auxiliaryBytes,
        metrics: {'adapter': 'jsonl', 'logExists': exists, 'indexExists': sidecarExists},
      );
    } on Object catch (error) {
      return CompositionLifecycleStorageHealth(
        state: CompositionLifecycleStorageHealthState.unavailable,
        checkedAt: DateTime.now().toUtc(),
        lastSuccessfulWriteAt: _lastSuccessfulWriteAt,
        lastError: error.toString(),
        metrics: const {'adapter': 'jsonl'},
      );
    }
  }

  Future<void> _appendOne(CompositionLifecycleEvent event) async {
    await file.parent.create(recursive: true);
    await _discardIncompleteTail();
    await _sparseIndex.ensureReady();

    final existing = await _sparseIndex.findEventById(event.eventId);
    if (existing != null) {
      if (_sameEvent(existing, event)) return;
      throw LifecycleEventIdentityConflictException(event.eventId);
    }

    final encoded = codec.encode(event);
    final recordBytes = utf8.encode(encoded);
    final offset = await file.exists() ? await file.length() : 0;
    final handle = await file.open(mode: FileMode.append);
    try {
      await handle.writeFrom(recordBytes);
      await handle.writeByte(0x0a);
      await handle.flush();
    } finally {
      await handle.close();
    }
    await _sparseIndex.append(
      event,
      offset: offset,
      endOffset: offset + recordBytes.length + 1,
      recordLength: recordBytes.length,
    );
  }

  /// Removes an unterminated tail left by an interrupted prior append before
  /// adding a new record. Without this repair, the next newline would turn the
  /// fragment into a malformed complete record.
  Future<void> _discardIncompleteTail() async {
    if (!await file.exists()) return;
    final handle = await file.open(mode: FileMode.read);
    int lastByte;
    try {
      final length = await handle.length();
      if (length == 0) return;
      await handle.setPosition(length - 1);
      lastByte = await handle.readByte();
    } finally {
      await handle.close();
    }
    if (lastByte == 0x0a) return;

    final bytes = await file.readAsBytes();
    final lastNewline = bytes.lastIndexOf(0x0a);
    await file.writeAsBytes(
      bytes.sublist(0, lastNewline + 1),
      mode: FileMode.write,
      flush: true,
    );
  }

  /// Removes events older than [retainFrom] and/or keeps only the newest
  /// [maxEvents] records.
  ///
  /// [retainFrom] is inclusive. When both arguments are supplied, the time
  /// filter is applied first and [maxEvents] then caps the remaining newest
  /// records. At least one policy must be supplied. Returns the number of
  /// records removed.
  ///
  /// The replacement is fully written and flushed before the current file is
  /// moved to a temporary backup and the replacement is renamed into place.
  /// If installing the replacement fails, the backup is restored. The
  /// temporary directory is always cleaned up best-effort.
  ///
  /// Compaction is serialized with append operations submitted to this
  /// instance. Like appends, it does not coordinate with other processes.
  Future<int> compact({
    DateTime? retainFrom,
    int? maxEvents,
  }) {
    if (retainFrom == null && maxEvents == null) {
      throw ArgumentError('Provide retainFrom, maxEvents, or both.');
    }
    if (maxEvents != null && maxEvents < 1) {
      throw ArgumentError.value(maxEvents, 'maxEvents', 'Must be greater than zero.');
    }
    return _enqueue(() => _compactOne(
          retainFrom: retainFrom,
          maxEvents: maxEvents,
        ));
  }

  Future<int> _compactOne({
    DateTime? retainFrom,
    int? maxEvents,
  }) async {
    if (!await file.exists()) return 0;

    final events = await _readAllCompleteEvents();
    final retained = <CompositionLifecycleEvent>[];
    for (final event in events) {
      if (retainFrom != null && event.timestamp.isBefore(retainFrom)) {
        continue;
      }
      retained.add(event);
    }

    final ordered = _stableChronological(retained);
    final capped = maxEvents != null && ordered.length > maxEvents
        ? ordered.skip(ordered.length - maxEvents).toList(growable: false)
        : ordered;
    final removed = events.length - capped.length;

    final tempDirectory = await file.parent.createTemp(
      '.${file.uri.pathSegments.isEmpty ? 'events' : file.uri.pathSegments.last}.compact-',
    );
    final replacement = File('${tempDirectory.path}/replacement.jsonl');
    final backup = File('${tempDirectory.path}/original.jsonl');
    var originalMoved = false;
    try {
      final sink = replacement.openWrite(mode: FileMode.writeOnly, encoding: utf8);
      try {
        for (final event in capped) {
          sink.writeln(codec.encode(event));
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      // Flush the replacement to the filesystem before touching the source.
      final replacementHandle = await replacement.open(mode: FileMode.append);
      try {
        await replacementHandle.flush();
      } finally {
        await replacementHandle.close();
      }

      await file.rename(backup.path);
      originalMoved = true;
      try {
        await replacement.rename(file.path);
        originalMoved = false;
      } catch (_) {
        if (originalMoved && await backup.exists()) {
          await backup.rename(file.path);
          originalMoved = false;
        }
        rethrow;
      }
      await _sparseIndex.invalidate();
      return removed;
    } finally {
      // If an unexpected failure happened after moving the original, make a
      // final best-effort restoration before removing temporary artifacts.
      if (originalMoved && await backup.exists() && !await file.exists()) {
        try {
          await backup.rename(file.path);
        } on FileSystemException {
          // Leave the backup in place rather than deleting the only copy.
        }
      }
      if (await tempDirectory.exists()) {
        try {
          await tempDirectory.delete(recursive: true);
        } on FileSystemException {
          // A retained backup is safer than risking data loss.
        }
      }
    }
  }

  @override
  Future<List<CompositionLifecycleEvent>> query(
    CompositionLifecycleEventQuery query,
  ) async {
    // Ensure queries observe all appends/compactions submitted before this call.
    await _writeTail;
    if (!await file.exists()) return const [];

    return _sparseIndex.query(query);
  }

  bool _sameEvent(
    CompositionLifecycleEvent left,
    CompositionLifecycleEvent right,
  ) {
    bool sameList(List<String> a, List<String> b) {
      if (a.length != b.length) return false;
      for (var index = 0; index < a.length; index++) {
        if (a[index] != b[index]) return false;
      }
      return true;
    }

    return left.eventId == right.eventId &&
        left.correlationId == right.correlationId &&
        left.operation == right.operation &&
        left.status == right.status &&
        left.timestamp.toUtc() == right.timestamp.toUtc() &&
        sameList(left.nodeIds, right.nodeIds) &&
        sameList(left.ownerIds, right.ownerIds) &&
        left.duration == right.duration &&
        left.errorType == right.errorType &&
        left.errorMessage == right.errorMessage;
  }

  Future<List<CompositionLifecycleEvent>> _readAllCompleteEvents() async {
    if (!await file.exists()) return const [];
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return const [];

    // Split at the byte-level newline delimiter. This also lets us ignore an
    // interrupted final UTF-8 sequence without weakening validation of any
    // newline-terminated record.
    final events = <CompositionLifecycleEvent>[];
    var start = 0;
    for (var index = 0; index < bytes.length; index++) {
      if (bytes[index] != 0x0a) continue;
      final lineBytes = bytes.sublist(start, index);
      start = index + 1;
      if (lineBytes.isEmpty) continue;
      final line = utf8.decode(lineBytes, allowMalformed: false);
      events.add(codec.decode(line));
    }
    // Bytes after the last newline are an incomplete record and are ignored.
    return events;
  }

  List<CompositionLifecycleEvent> _stableChronological(
    List<CompositionLifecycleEvent> events,
  ) {
    final indexed = events.indexed.toList();
    indexed.sort((a, b) {
      final byTime = a.$2.timestamp.compareTo(b.$2.timestamp);
      if (byTime != 0) return byTime;
      final byId = a.$2.eventId.compareTo(b.$2.eventId);
      return byId != 0 ? byId : a.$1.compareTo(b.$1);
    });
    return indexed.map((entry) => entry.$2).toList(growable: false);
  }


}


/// Backwards-compatible name for the storage-neutral API exception.
typedef LifecycleEventIdentityConflictException =
    CompositionLifecycleEventIdentityConflictException;
