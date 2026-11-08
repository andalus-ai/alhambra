import 'package:meta/meta.dart';

/// Standard pagination request parameters.
@immutable
final class Pagination {
  /// 1-based page index.
  final int page;

  /// Number of records per page.
  final int pageSize;

  const Pagination({
    this.page = 1,
    this.pageSize = 20,
  }) : assert(page >= 1, 'Page must be >= 1'),
       assert(pageSize >= 1, 'PageSize must be >= 1');

  /// Zero-based offset calculation.
  int get offset => (page - 1) * pageSize;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Pagination &&
          runtimeType == other.runtimeType &&
          other.page == page &&
          other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(page, pageSize);

  @override
  String toString() => 'Pagination(page: $page, size: $pageSize)';
}
