import 'dart:convert';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

/// Versioned JSON codec for durable composition lifecycle event records.
///
/// This codec is storage-neutral: file, database, and remote adapters can use
/// it without making the public plugin API depend on a serialization format.
final class CompositionLifecycleEventJsonCodec {
  static const int currentSchemaVersion = 2;

  const CompositionLifecycleEventJsonCodec();

  String encode(CompositionLifecycleEvent event) {
    return jsonEncode(<String, Object?>{
      'schemaVersion': currentSchemaVersion,
      'eventId': event.eventId,
      'correlationId': event.correlationId,
      'operation': event.operation.name,
      'status': event.status.name,
      'timestamp': event.timestamp.toUtc().toIso8601String(),
      'nodeIds': event.nodeIds,
      'ownerIds': event.ownerIds,
      if (event.duration != null)
        'durationMicros': event.duration!.inMicroseconds,
      if (event.errorType != null) 'errorType': event.errorType,
      if (event.errorMessage != null) 'errorMessage': event.errorMessage,
    });
  }

  CompositionLifecycleEvent decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      rethrow;
    }
    if (decoded is! Map) {
      throw const FormatException('Lifecycle event must be a JSON object.');
    }

    final value = Map<String, Object?>.from(decoded);
    final version = value['schemaVersion'];
    if (version != 1 && version != currentSchemaVersion) {
      throw FormatException(
        'Unsupported lifecycle event schema $version; supported versions are 1 and $currentSchemaVersion.',
      );
    }

    final correlationId = _requiredString(value, 'correlationId');
    final operation = _enumValue(
      CompositionLifecycleOperation.values,
      _requiredString(value, 'operation'),
      'operation',
    );
    final status = _enumValue(
      CompositionLifecycleStatus.values,
      _requiredString(value, 'status'),
      'status',
    );
    final timestampSource = _requiredString(value, 'timestamp');
    final timestamp = DateTime.tryParse(timestampSource);
    if (timestamp == null) {
      throw const FormatException('Invalid lifecycle event timestamp.');
    }

    final nodeIds = _stringList(value, 'nodeIds');
    final ownerIds = _stringList(value, 'ownerIds');
    final durationMicros = value['durationMicros'];
    if (durationMicros != null &&
        (durationMicros is! int || durationMicros < 0)) {
      throw const FormatException('durationMicros must be a non-negative integer.');
    }

    final eventId = version == 1
        ? 'legacy-${base64Url.encode(utf8.encode(source))}'
        : _requiredString(value, 'eventId');

    return CompositionLifecycleEvent(
      eventId: eventId,
      correlationId: correlationId,
      operation: operation,
      status: status,
      timestamp: timestamp,
      nodeIds: nodeIds,
      ownerIds: ownerIds,
      duration: durationMicros == null
          ? null
          : Duration(microseconds: durationMicros as int),
      errorType: _optionalString(value, 'errorType'),
      errorMessage: _optionalString(value, 'errorMessage'),
    );
  }

  String _requiredString(Map<String, Object?> value, String key) {
    final item = value[key];
    if (item is! String || item.isEmpty) {
      throw FormatException('Expected non-empty string "$key".');
    }
    return item;
  }

  String? _optionalString(Map<String, Object?> value, String key) {
    final item = value[key];
    if (item != null && item is! String) {
      throw FormatException('Expected "$key" to be a string or null.');
    }
    return item as String?;
  }

  List<String> _stringList(Map<String, Object?> value, String key) {
    final item = value[key];
    if (item is! List || item.any((entry) => entry is! String)) {
      throw FormatException('Expected "$key" to be a list of strings.');
    }
    return List<String>.unmodifiable(item.cast<String>());
  }

  T _enumValue<T extends Enum>(List<T> values, String name, String field) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('Unknown lifecycle event $field "$name".');
  }
}
