import 'dart:convert';
import 'dart:io';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

/// Persistent sparse checkpoints over the authoritative append-only JSONL log.
/// Full blocks are checkpointed every 128 records; an incomplete tail is never
/// treated as indexed. A missing or invalid sidecar is safely rebuilt.
final class JsonlSparseLifecycleIndex {
  static const int blockSize = 128;
  static const int _schemaVersion = 1;

  final File logFile;
  final CompositionLifecycleEventJsonCodec codec;
  late final File _indexFile = File('\${logFile.path}.sparse-index.json');

  final List<_SparseBlock> _blocks = [];
  final List<CompositionLifecycleEvent> _pending = [];
  final List<int> _pendingOffsets = [];
  int _indexedLength = 0;
  bool _ready = false;

  JsonlSparseLifecycleIndex({required this.logFile, required this.codec});

  Future<void> ensureReady() async {
    if (_ready) return;
    _blocks.clear();
    _pending.clear();
    _pendingOffsets.clear();
    _indexedLength = 0;
    if (!await logFile.exists()) {
      _ready = true;
      return;
    }
    final length = await logFile.length();
    await _loadCheckpoint(length);
    if (_indexedLength < length) await _readTail(_indexedLength, length);
    _ready = true;
  }

  Future<void> append(
    CompositionLifecycleEvent event, {
    required int offset,
    required int endOffset,
    required int recordLength,
  }) async {
    await ensureReady();
    if (_pending.isEmpty) _pendingOffsets.clear();
    _pending.add(event);
    _pendingOffsets.add(offset);
    if (_pending.length == blockSize) {
      _blocks.add(_SparseBlock.fromEvents(
        offset: _pendingOffsets.first,
        endOffset: endOffset,
        events: List.of(_pending),
        lastRecordOffset: offset,
        lastRecordLength: recordLength,
      ));
      _pending.clear();
      _pendingOffsets.clear();
      _indexedLength = endOffset;
      await _persistCheckpoint();
    }
  }

  Future<CompositionLifecycleEvent?> findEventById(String eventId) async {
    await ensureReady();
    for (final block in _blocks) {
      if (!block.mightContain(eventId)) continue;
      for (final event in await _readBlock(block)) {
        if (event.eventId == eventId) return event;
      }
    }
    for (final event in _pending) {
      if (event.eventId == eventId) return event;
    }
    return null;
  }

  Future<bool> containsEventId(String eventId) async {
    await ensureReady();
    for (final block in _blocks) {
      if (!block.mightContain(eventId)) continue;
      if ((await _readBlock(block)).any((event) => event.eventId == eventId)) {
        return true;
      }
    }
    return _pending.any((event) => event.eventId == eventId);
  }

  Future<List<CompositionLifecycleEvent>> query(
    CompositionLifecycleEventQuery query,
  ) async {
    await ensureReady();
    final matches = <CompositionLifecycleEvent>[];
    for (final block in _blocks) {
      if (!_blockMayMatch(block, query)) continue;
      for (final event in await _readBlock(block)) {
        if (_matches(event, query)) matches.add(event);
      }
    }
    for (final event in _pending) {
      if (_matches(event, query)) matches.add(event);
    }
    matches.sort(_compareEvents);
    if (query.beforeCursor != null && matches.length > query.limit) {
      return List.unmodifiable(matches.skip(matches.length - query.limit));
    }
    return List.unmodifiable(matches.take(query.limit));
  }

  Future<void> invalidate() async {
    _ready = false;
    _blocks.clear();
    _pending.clear();
    _pendingOffsets.clear();
    _indexedLength = 0;
    if (await _indexFile.exists()) await _indexFile.delete();
  }

  Future<void> _loadCheckpoint(int fileLength) async {
    if (!await _indexFile.exists()) return;
    try {
      final decoded = jsonDecode(await _indexFile.readAsString());
      if (decoded is! Map ||
          decoded['schemaVersion'] != _schemaVersion ||
          decoded['indexedLength'] is! int ||
          decoded['blocks'] is! List) return;
      final indexedLength = decoded['indexedLength'] as int;
      if (indexedLength < 0 || indexedLength > fileLength) return;
      final blocks = (decoded['blocks'] as List)
          .map((value) => _SparseBlock.fromJson(Map<String, Object?>.from(value as Map)))
          .toList(growable: false);
      if (blocks.isNotEmpty) {
        if (blocks.last.endOffset != indexedLength) return;
        final last = blocks.last;
        final event = await _readEventAt(last.lastRecordOffset, last.lastRecordLength);
        if (event.eventId != last.lastEventId) return;
      } else if (indexedLength != 0) {
        return;
      }
      _blocks.addAll(blocks);
      _indexedLength = indexedLength;
    } on Object {
      _blocks.clear();
      _indexedLength = 0;
    }
  }

  Future<void> _readTail(int startOffset, int endOffset) async {
    final bytes = await logFile.openRead(startOffset, endOffset).fold<List<int>>(
      <int>[], (buffer, chunk) => buffer..addAll(chunk));
    var lineStart = 0;
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] != 0x0a) continue;
      final line = bytes.sublist(lineStart, i);
      final absoluteStart = startOffset + lineStart;
      lineStart = i + 1;
      if (line.isEmpty) continue;
      final event = codec.decode(utf8.decode(line, allowMalformed: false));
      if (_pending.isEmpty) _pendingOffsets.clear();
      _pending.add(event);
      _pendingOffsets.add(absoluteStart);
      if (_pending.length == blockSize) {
        _blocks.add(_SparseBlock.fromEvents(
          offset: _pendingOffsets.first,
          endOffset: startOffset + i + 1,
          events: List.of(_pending),
          lastRecordOffset: absoluteStart,
          lastRecordLength: line.length,
        ));
        _pending.clear();
        _pendingOffsets.clear();
        _indexedLength = startOffset + i + 1;
      }
    }
    if (_indexedLength > 0) await _persistCheckpoint();
  }

  Future<List<CompositionLifecycleEvent>> _readBlock(_SparseBlock block) async {
    final stream = logFile.openRead(block.offset, block.endOffset)
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    final events = <CompositionLifecycleEvent>[];
    await for (final line in stream) {
      if (line.isNotEmpty) events.add(codec.decode(line));
    }
    return events;
  }

  Future<CompositionLifecycleEvent> _readEventAt(int offset, int length) async {
    final bytes = await logFile.openRead(offset, offset + length).fold<List<int>>(
      <int>[], (buffer, chunk) => buffer..addAll(chunk));
    return codec.decode(utf8.decode(bytes, allowMalformed: false));
  }

  Future<void> _persistCheckpoint() async {
    final payload = jsonEncode({
      'schemaVersion': _schemaVersion,
      'indexedLength': _indexedLength,
      'blocks': _blocks.map((block) => block.toJson()).toList(),
    });
    final temp = File('\${_indexFile.path}.tmp');
    await temp.parent.create(recursive: true);
    final handle = await temp.open(mode: FileMode.write);
    try {
      await handle.writeString(payload, encoding: utf8);
      await handle.flush();
    } finally {
      await handle.close();
    }
    if (await _indexFile.exists()) await _indexFile.delete();
    await temp.rename(_indexFile.path);
  }

  bool _blockMayMatch(_SparseBlock block, CompositionLifecycleEventQuery query) {
    if (query.from != null && block.maxTimestamp.isBefore(query.from!)) return false;
    if (query.to != null && block.minTimestamp.isAfter(query.to!)) return false;
    if (query.before != null && !block.minTimestamp.isBefore(query.before!)) return false;
    if (query.after != null && _compareKey(block.maxTimestamp, block.maxEventId, query.after!) <= 0) return false;
    if (query.beforeCursor != null && _compareKey(block.minTimestamp, block.minEventId, query.beforeCursor!) >= 0) return false;
    return true;
  }

  bool _matches(CompositionLifecycleEvent event, CompositionLifecycleEventQuery query) {
    if (query.correlationId != null && event.correlationId != query.correlationId) return false;
    if (query.ownerId != null && !event.ownerIds.contains(query.ownerId)) return false;
    if (query.operation != null && event.operation != query.operation) return false;
    if (query.status != null && event.status != query.status) return false;
    if (query.from != null && event.timestamp.isBefore(query.from!)) return false;
    if (query.to != null && event.timestamp.isAfter(query.to!)) return false;
    if (query.before != null && !event.timestamp.isBefore(query.before!)) return false;
    if (query.after != null && _compareKey(event.timestamp, event.eventId, query.after!) <= 0) return false;
    if (query.beforeCursor != null && _compareKey(event.timestamp, event.eventId, query.beforeCursor!) >= 0) return false;
    return true;
  }

  int _compareEvents(CompositionLifecycleEvent left, CompositionLifecycleEvent right) {
    final byTime = left.timestamp.compareTo(right.timestamp);
    return byTime != 0 ? byTime : left.eventId.compareTo(right.eventId);
  }

  int _compareKey(DateTime timestamp, String eventId, CompositionLifecycleEventCursor cursor) {
    final byTime = timestamp.compareTo(cursor.timestamp);
    return byTime != 0 ? byTime : eventId.compareTo(cursor.eventId);
  }
}

final class _SparseBlock {
  final int offset, endOffset, count, lastRecordOffset, lastRecordLength;
  final DateTime minTimestamp, maxTimestamp;
  final String minEventId, maxEventId, lastEventId;
  final List<int> bloom;

  _SparseBlock({
    required this.offset, required this.endOffset, required this.count,
    required this.minTimestamp, required this.minEventId,
    required this.maxTimestamp, required this.maxEventId,
    required this.lastRecordOffset, required this.lastRecordLength,
    required this.lastEventId, required this.bloom,
  });

  factory _SparseBlock.fromEvents({
    required int offset, required int endOffset,
    required List<CompositionLifecycleEvent> events,
    required int lastRecordOffset, required int lastRecordLength,
  }) {
    var min = events.first, max = events.first;
    final bloom = List<int>.filled(32, 0);
    for (final event in events) {
      if (_compare(event, min) < 0) min = event;
      if (_compare(event, max) > 0) max = event;
      _addBloom(bloom, event.eventId);
    }
    return _SparseBlock(
      offset: offset, endOffset: endOffset, count: events.length,
      minTimestamp: min.timestamp.toUtc(), minEventId: min.eventId,
      maxTimestamp: max.timestamp.toUtc(), maxEventId: max.eventId,
      lastRecordOffset: lastRecordOffset, lastRecordLength: lastRecordLength,
      lastEventId: events.last.eventId, bloom: bloom,
    );
  }

  bool mightContain(String id) => _bloomPositions(id).every(
      (p) => (bloom[p >> 3] & (1 << (p & 7))) != 0);

  Map<String, Object?> toJson() => {
    'offset': offset, 'endOffset': endOffset, 'count': count,
    'minTimestamp': minTimestamp.toIso8601String(), 'minEventId': minEventId,
    'maxTimestamp': maxTimestamp.toIso8601String(), 'maxEventId': maxEventId,
    'lastRecordOffset': lastRecordOffset, 'lastRecordLength': lastRecordLength,
    'lastEventId': lastEventId, 'bloom': base64Encode(bloom),
  };

  factory _SparseBlock.fromJson(Map<String, Object?> value) {
    final bloom = base64Decode(value['bloom'] as String);
    final min = DateTime.tryParse(value['minTimestamp'] as String? ?? '');
    final max = DateTime.tryParse(value['maxTimestamp'] as String? ?? '');
    const ints = ['offset', 'endOffset', 'count', 'lastRecordOffset', 'lastRecordLength'];
    if (bloom.length != 32 || min == null || max == null ||
        ints.any((key) => value[key] is! int) ||
        value['minEventId'] is! String || value['maxEventId'] is! String ||
        value['lastEventId'] is! String) {
      throw const FormatException('Invalid sparse lifecycle index block.');
    }
    final block = _SparseBlock(
      offset: value['offset'] as int, endOffset: value['endOffset'] as int,
      count: value['count'] as int, minTimestamp: min, minEventId: value['minEventId'] as String,
      maxTimestamp: max, maxEventId: value['maxEventId'] as String,
      lastRecordOffset: value['lastRecordOffset'] as int,
      lastRecordLength: value['lastRecordLength'] as int,
      lastEventId: value['lastEventId'] as String, bloom: bloom,
    );
    if (block.offset < 0 || block.endOffset <= block.offset ||
        block.count != JsonlSparseLifecycleIndex.blockSize ||
        block.lastRecordOffset < block.offset ||
        block.lastRecordOffset + block.lastRecordLength > block.endOffset) {
      throw const FormatException('Invalid sparse lifecycle index offsets.');
    }
    return block;
  }
}

int _compare(CompositionLifecycleEvent a, CompositionLifecycleEvent b) {
  final byTime = a.timestamp.compareTo(b.timestamp);
  return byTime != 0 ? byTime : a.eventId.compareTo(b.eventId);
}

void _addBloom(List<int> bloom, String value) {
  for (final position in _bloomPositions(value)) {
    bloom[position >> 3] |= 1 << (position & 7);
  }
}

List<int> _bloomPositions(String value) {
  const mask = 0xffffffff;
  var first = 0x811c9dc5, second = 0x9e3779b9;
  for (final unit in value.codeUnits) {
    first = ((first ^ unit) * 0x01000193) & mask;
    second = ((second ^ unit) * 0x85ebca6b) & mask;
  }
  final a = first % 256, b = (second | 1) % 256;
  return [a, (a + b) % 256, (a + 2 * b) % 256];
}
