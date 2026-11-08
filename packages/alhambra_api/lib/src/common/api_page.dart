/// Paged collection envelope for API list responses.
final class ApiPage<T> {
  final List<T> items;
  final int page;
  final int pageSize;
  final int? total;
  final bool hasNext;

  const ApiPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.hasNext,
    this.total,
  });

  @override
  String toString() =>
      'ApiPage(page: $page, size: $pageSize, items: ${items.length}, total: $total, hasNext: $hasNext)';
}
