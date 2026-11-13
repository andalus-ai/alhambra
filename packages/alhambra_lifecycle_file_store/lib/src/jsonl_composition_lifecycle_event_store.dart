import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

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
    implements CompositionLifecycleEventStore {
  final File file;
  final CompositionLifecycleEventJsonCodec codec;

  Future<void> _writeTail = Future<void>.value();

  // Rebuilt once from the authoritative JSONL log and maintained on append.
  // These indexes avoid replaying the file for every query in this process.
  bool _indexReady = false;
  final Map<String, CompositionLifecycleEvent> _eventsById = {};
  final Map<String, Set<String>> _byCorrelation = {};
  final Map<String, Set<String>> _byOwner = {};
  final Map<String, Set<String>> _byOperation = {};
  final Map<String, Set<String>> _byStatus = {};

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
  Future<void> append(CompositionLifecycleEvent event) =>
      _enqueue(() => _appendOne(event));

  Future<void> _appendOne(CompositionLifecycleEvent event) async {
    await file.parent.create(recursive: true);
    await _discardIncompleteTail();
    await _ensureIndex();

    final existing = _eventsById[event.eventId];
    if (existing != null) {
      if (_sameEvent(existing, event)) return;
      throw LifecycleEventIdentityConflictException(event.eventId);
    }

    final encoded = codec.encode(event);
    final handle = await file.open(mode: FileMode.append);
    try {
      await handle.writeString('$encoded\\n', encoding: utf8);
      await handle.flush();
    } finally {
      await handle.close();
    }
    _addToIndex(event);
  }

  /// Removes an unterminated tail left by an interrupted prior append before
  /// adding a new record. Without this repair, the next newline would turn the
  /// fragment into a malformed complete record.
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
      _clearIndex();
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

    await _ensureIndex();
    final candidates = _candidateEvents(query);
    final ordered = _stableChronological(
      candidates.where((event) => _matches(event, query)).toList(),
    );
    if (query.beforeCursor != null) {
      final preceding = ordered
          .where((event) => _compareEventToCursor(event, query.beforeCursor!) < 0)
          .toList();
      final start = preceding.length > query.limit
          ? preceding.length - query.limit
          : 0;
      return List<CompositionLifecycleEvent>.unmodifiable(preceding.skip(start));
    }
    return List<CompositionLifecycleEvent>.unmodifiable(ordered.take(query.limit));
  }

  Future<void> _ensureIndex() async {
    if (_indexReady) return;
    _clearIndex();
    final events = await _readAllCompleteEvents();
    for (final event in events) {
      final existing = _eventsById[event.eventId];
      if (existing == null) {
        _addToIndex(event);
      } else if (!_sameEvent(existing, event)) {
        throw FormatException(
          'Conflicting lifecycle event ID "${event.eventId}" in JSONL history.',
        );
      }
      // Identical historical duplicates are collapsed in the query index.
    }
    _indexReady = true;
  }

  void _clearIndex() {
    _eventsById.clear();
    _byCorrelation.clear();
    _byOwner.clear();
    _byOperation.clear();
    _byStatus.clear();
    _indexReady = false;
  }

  void _addToIndex(CompositionLifecycleEvent event) {
    _eventsById[event.eventId] = event;
    _byCorrelation.putIfAbsent(event.correlationId, () => <String>{}).add(event.eventId);
    for (final ownerId in event.ownerIds) {
      _byOwner.putIfAbsent(ownerId, () => <String>{}).add(event.eventId);
    }
    _byOperation.putIfAbsent(event.operation.name, () => <String>{}).add(event.eventId);
    _byStatus.putIfAbsent(event.status.name, () => <String>{}).add(event.eventId);
    _indexReady = true;
  }

  List<CompositionLifecycleEvent> _candidateEvents(
    CompositionLifecycleEventQuery query,
  ) {
    Set<String>? candidateIds;
    void intersect(Set<String>? next) {
      if (next == null) {
        candidateIds = <String>{};
      } else if (candidateIds == null) {
        candidateIds = Set<String>.of(next);
      } else {
        candidateIds!.retainAll(next);
      }
    }

    if (query.correlationId != null) intersect(_byCorrelation[query.correlationId]);
    if (query.ownerId != null) intersect(_byOwner[query.ownerId]);
    if (query.operation != null) intersect(_byOperation[query.operation!.name]);
    if (query.status != null) intersect(_byStatus[query.status!.name]);

    final ids = candidateIds ?? _eventsById.keys.toSet();
    return ids.map((id) => _eventsById[id]!).toList(growable: false);
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

  int _compareEventToCursor(CompositionLifecycleEvent event, CompositionLifecycleEventCursor cursor) {
    final byTime = event.timestamp.compareTo(cursor.timestamp);
    return byTime != 0 ? byTime : event.eventId.compareTo(cursor.eventId);
  }

  bool _matches(
    CompositionLifecycleEvent event,
    CompositionLifecycleEventQuery query,
  ) {
    if (query.correlationId != null &&
        event.correlationId != query.correlationId) {
      return false;
    }
    if (query.ownerId != null && !event.ownerIds.contains(query.ownerId)) {
      return false;
    }
    if (query.operation != null && event.operation != query.operation) {
      return false;
    }
    if (query.status != null && event.status != query.status) {
      return false;
    }
    if (query.from != null && event.timestamp.isBefore(query.from!)) {
      return false;
    }
    if (query.to != null && event.timestamp.isAfter(query.to!)) {
      return false;
    }
    if (query.before != null && !event.timestamp.isBefore(query.before!)) return false;
    if (query.after != null && _compareEventToCursor(event, query.after!) <= 0) return false;
    if (query.beforeCursor != null && _compareEventToCursor(event, query.beforeCursor!) >= 0) return false;
    return true;
  }
}


/// Reusing an event ID with a different payload is a persistence conflict.
/// Retrying the same event ID and payload is an idempotent no-op.
final class LifecycleEventIdentityConflictException implements Exception {
  final String eventId;

  const LifecycleEventIdentityConflictException(this.eventId);

  @override
  String toString() =>
      'Lifecycle event ID "$eventId" already exists with a different payload.';
}
