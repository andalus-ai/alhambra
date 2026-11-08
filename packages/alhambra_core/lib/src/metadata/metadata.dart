import 'package:meta/meta.dart';

/// Immutable key-value metadata container with typed extraction helpers.
@immutable
final class Metadata {
  final Map<String, Object?> _data;

  const Metadata([this._data = const {}]);

  /// Returns value associated with [key].
  Object? operator [](String key) => _data[key];

  /// Returns typed value or null.
  T? get<T>(String key) {
    final val = _data[key];
    return val is T ? val : null;
  }

  /// Whether [key] is present in metadata.
  bool containsKey(String key) => _data.containsKey(key);

  /// Map view of all metadata entries.
  Map<String, Object?> toMap() => Map.unmodifiable(_data);

  /// Creates a new [Metadata] instance merged with additional entries.
  Metadata copyWith(Map<String, Object?> updates) {
    return Metadata({..._data, ...updates});
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Metadata &&
          runtimeType == other.runtimeType &&
          _mapsEqual(_data, other._data);

  @override
  int get hashCode => Object.hashAll(_data.entries);

  @override
  String toString() => 'Metadata($_data)';

  static bool _mapsEqual(Map<String, Object?> a, Map<String, Object?> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
