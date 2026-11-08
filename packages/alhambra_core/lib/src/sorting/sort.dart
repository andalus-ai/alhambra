import 'package:meta/meta.dart';

/// Sort direction.
enum SortDirection {
  ascending,
  descending,
}

/// Ordering specification for listing and querying resources.
@immutable
final class Sort {
  /// Field to sort on (e.g. 'createdAt', 'name').
  final String field;

  /// Sort direction.
  final SortDirection direction;

  const Sort(this.field, [this.direction = SortDirection.ascending]);

  const Sort.desc(this.field) : direction = SortDirection.descending;

  const Sort.asc(this.field) : direction = SortDirection.ascending;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Sort &&
          runtimeType == other.runtimeType &&
          other.field == field &&
          other.direction == direction;

  @override
  int get hashCode => Object.hash(field, direction);

  @override
  String toString() => 'Sort($field ${direction.name})';
}
