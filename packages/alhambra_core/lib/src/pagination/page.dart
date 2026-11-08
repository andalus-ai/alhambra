import 'package:meta/meta.dart';

/// Container for a paginated subset of domain items.
@immutable
final class Page<T> {
  /// The collection of elements in this page.
  final List<T> items;

  /// Current 1-based page number.
  final int page;

  /// Requested page size.
  final int pageSize;

  /// Whether more items are available on subsequent pages.
  final bool hasNext;

  /// Optional total count of matching items across all pages.
  final int? totalCount;

  const Page({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.hasNext,
    this.totalCount,
  });

  /// Total number of pages if [totalCount] is known.
  int? get totalPages => totalCount != null ? (totalCount! / pageSize).ceil() : null;

  /// Whether this is the first page.
  bool get isFirst => page == 1;

  /// Whether this is the last page (if known or hasNext is false).
  bool get isLast => !hasNext;

  /// Maps the items of this page to another type.
  Page<R> map<R>(R Function(T item) transform) {
    return Page<R>(
      items: items.map(transform).toList(),
      page: page,
      pageSize: pageSize,
      hasNext: hasNext,
      totalCount: totalCount,
    );
  }

  @override
  String toString() => 'Page(page: $page, size: $pageSize, count: ${items.length}, hasNext: $hasNext)';
}
