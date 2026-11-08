import 'package:meta/meta.dart';
import '../identifier/alhambra_id.dart';

/// Common audit and temporal metadata carried by any Alhambra resource.
@immutable
final class ResourceMetadata {
  /// Unique identifier of the resource.
  final AlhambraId id;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last modification timestamp.
  final DateTime updatedAt;

  /// Optional actor/user ID who created the resource.
  final String? createdBy;

  /// Optional actor/user ID who last updated the resource.
  final String? updatedBy;

  /// Monotonically increasing revision version for optimistic locking.
  final int version;

  const ResourceMetadata({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.version = 1,
  });

  ResourceMetadata copyWith({
    AlhambraId? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    int? version,
  }) {
    return ResourceMetadata(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      version: version ?? this.version,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResourceMetadata &&
          runtimeType == other.runtimeType &&
          other.id == id &&
          other.version == version &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, version, createdAt, updatedAt);

  @override
  String toString() => 'ResourceMetadata(id: $id, v: $version)';
}
