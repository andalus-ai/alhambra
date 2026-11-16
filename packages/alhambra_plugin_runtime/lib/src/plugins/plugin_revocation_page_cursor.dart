import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'plugin_revocation_scoped_queries.dart';

/// Authenticated continuation codec shared by durable revocation adapters.
///
/// Hosts must supply the same randomly generated secret (at least 256 bits)
/// to every adapter instance and preserve it across restarts. Do not derive it
/// from a database URL, tenant ID, or other public configuration.
final class PluginRevocationPageCursorCodec {
  final List<int> _secret;

  PluginRevocationPageCursorCodec(List<int> secret)
      : _secret = List.unmodifiable(secret) {
    if (secret.length < 32) {
      throw ArgumentError.value(
        secret.length,
        'secret',
        'Cursor signing secret must contain at least 32 bytes.',
      );
    }
  }

  String encode({
    required String family,
    required PluginRevocationScopedQuery query,
    required List<String> filters,
    required DateTime snapshotAt,
    required DateTime lastAt,
    required String lastId,
  }) {
    final payload = <String, Object?>{
      'v': 1,
      'family': family,
      'scope': query.scopeId,
      'from': query.fromInclusive?.toUtc().toIso8601String(),
      'to': query.toExclusive?.toUtc().toIso8601String(),
      'size': query.pageSize,
      'filters': [...filters]..sort(),
      'snapshot': snapshotAt.toUtc().toIso8601String(),
      'lastAt': lastAt.toUtc().toIso8601String(),
      'lastId': lastId,
    };
    final encoded = base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
    final signature = _sign(encoded);
    return '$encoded.$signature';
  }

  PluginRevocationPageCursorPosition decode({
    required String token,
    required String family,
    required PluginRevocationScopedQuery query,
    required List<String> filters,
  }) {
    try {
      if (token.length > 4096) throw const FormatException();
      final parts = token.split('.');
      if (parts.length != 2 || parts.first.isEmpty || parts.last.isEmpty) {
        throw const FormatException();
      }
      final expected = _sign(parts.first);
      if (!_constantTimeEquals(expected, parts.last)) {
        throw const FormatException();
      }
      final normalized = base64Url.normalize(parts.first);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      final expectedFilters = [...filters]..sort();
      final actualFilters = (decoded['filters'] as List<dynamic>).cast<String>();
      actualFilters.sort();
      if (decoded['v'] != 1 ||
          decoded['family'] != family ||
          decoded['scope'] != query.scopeId ||
          decoded['from'] != query.fromInclusive?.toUtc().toIso8601String() ||
          decoded['to'] != query.toExclusive?.toUtc().toIso8601String() ||
          decoded['size'] != query.pageSize ||
          jsonEncode(actualFilters) != jsonEncode(expectedFilters)) {
        throw const FormatException();
      }
      return PluginRevocationPageCursorPosition(
        snapshotAt: DateTime.parse(decoded['snapshot'] as String).toUtc(),
        lastAt: DateTime.parse(decoded['lastAt'] as String).toUtc(),
        lastId: decoded['lastId'] as String,
      );
    } on Object {
      throw const PluginRevocationInvalidCursorException();
    }
  }

  String _sign(String value) =>
      base64Url.encode(Hmac(sha256, _secret).convert(utf8.encode(value)).bytes)
          .replaceAll('=', '');

  bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var i = 0; i < left.length; i++) {
      difference |= left.codeUnitAt(i) ^ right.codeUnitAt(i);
    }
    return difference == 0;
  }
}

final class PluginRevocationPageCursorPosition {
  final DateTime snapshotAt;
  final DateTime lastAt;
  final String lastId;

  const PluginRevocationPageCursorPosition({
    required this.snapshotAt,
    required this.lastAt,
    required this.lastId,
  });
}
