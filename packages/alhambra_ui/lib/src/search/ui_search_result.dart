/// UI-facing search result model.
///
/// This presentation DTO deliberately does not depend on a search backend or
/// service package. Adopters map their own search result types into this model.
final class UiSearchResult {
  final String resourceId;
  final String resourceType;
  final String title;
  final String? description;

  const UiSearchResult({
    required this.resourceId,
    required this.resourceType,
    required this.title,
    this.description,
  });
}

/// Asynchronous search callback supplied by the host application.
typedef UiSearchHandler = Future<List<UiSearchResult>> Function(
  String query, {
  String? scopeId,
});
