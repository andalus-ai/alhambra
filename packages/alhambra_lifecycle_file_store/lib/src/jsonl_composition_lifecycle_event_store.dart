import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

/// Append-only JSON Lines store for composition lifecycle events.
///
/// Each line is a self-contained, versioned event record. Appends are
/// serialized within this store instance and flushed before [append]
/// completes. The file is opened per operation, so the store does not hold
/// file handles across application suspension or shutdown.
///
/// This implementation is intended for a single-process writer. Multiple
/// processes writing the same file require an external lock or a different
/// storage adapter.
final class JsonlCompositionLifecycleEventStore
    implements CompositionLifecycleEventStore {
  final File file;
  final CompositionLifecycleEventJsonCodec codec;

  Future<void> _writeTail = Future<void>.value();

  JsonlCompositionLifecycleEventStore({
    required this.file,
    CompositionLifecycleEventJsonCodec? codec,
  }) : codec = codec ?? const CompositionLifecycleEventJsonCodec();

  @override
  Future<void> append(CompositionLifecycleEvent event) {
    final operation = _writeTail.then((_) => _appendOne(event));
    // Keep the queue usable after a failed append while returning the failure
    // to the caller that submitted this event.
    _writeTail = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _appendOne(CompositionLifecycleEvent event) async {
    await file.parent.create(recursive: true);
    final handle = await file.open(mode: FileMode.append);
    try {
      await handle.writeString('${codec.encode(event)}\n', encoding: utf8);
      await handle.flush();
    } finally {
      await handle.close();
    }
  }

  @override
  Future<List<CompositionLifecycleEvent>> query(
    CompositionLifecycleEventQuery query,
  ) async {
    // Ensure queries observe all appends submitted before this call.
    await _writeTail;
    if (!await file.exists()) return const [];

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return const [];
    final text = utf8.decode(bytes, allowMalformed: false);
    final hasCompleteFinalLine = text.endsWith('\n');
    final lines = text.split('\n');
    if (hasCompleteFinalLine) {
      lines.removeLast();
    } else {
      // A crash may leave only the final record incomplete. Ignore that
      // fragment; malformed records terminated by newline remain corruption.
      lines.removeLast();
    }

    final matches = <CompositionLifecycleEvent>[];
    for (final line in lines) {
      if (line.isEmpty) continue;
      final event = codec.decode(line);
      if (!_matches(event, query)) continue;
      matches.add(event);
    }

    matches.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (matches.length <= query.limit) {
      return List<CompositionLifecycleEvent>.unmodifiable(matches);
    }
    return List<CompositionLifecycleEvent>.unmodifiable(
      matches.take(query.limit),
    );
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
    if (query.before != null && !event.timestamp.isBefore(query.before!)) {
      return false;
    }
    return true;
  }
}
