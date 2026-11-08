import 'package:meta/meta.dart';

/// Generic conflict presentation data for the UI layer.
///
/// The actual resolution strategy remains with the repository/domain.
/// This model is infrastructure-only — no domain types.
@immutable
final class ConflictInfo {
  /// Domain resource type (e.g. `'workspace'`).
  final String resourceType;

  /// The specific resource ID that has a conflict.
  final String resourceId;

  /// Local state at the time of conflict (opaque to this layer).
  final Object? local;

  /// Remote authoritative state (opaque to this layer).
  final Object? remote;

  /// Names of the fields that differ between local and remote.
  final List<String> conflictingFields;

  const ConflictInfo({
    required this.resourceType,
    required this.resourceId,
    this.local,
    this.remote,
    this.conflictingFields = const [],
  });

  @override
  String toString() =>
      'ConflictInfo($resourceType/$resourceId, '
      'fields: ${conflictingFields.join(", ")})';
}
