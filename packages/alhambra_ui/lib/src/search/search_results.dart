import 'package:flutter/material.dart';
import '../states/empty_state.dart';
import '../states/error_state.dart';
import 'ui_search_result.dart';

/// Renders a list of application-provided [UiSearchResult] values.
class SearchResultsView extends StatelessWidget {
  final List<UiSearchResult> results;
  final ValueChanged<UiSearchResult>? onResultSelected;
  final bool isLoading;
  final String? errorMessage;

  const SearchResultsView({
    super.key,
    required this.results,
    this.onResultSelected,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return ErrorState(
        title: 'Search unavailable',
        message: errorMessage,
      );
    }

    if (results.isEmpty) {
      return const EmptyState(
        title: 'No results found',
        message: 'Try adjusting your search terms or filters',
      );
    }

    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = results[index];
        return ListTile(
          title: Text(result.title),
          subtitle: result.description != null ? Text(result.description!) : null,
          trailing: Chip(
            label: Text(
              result.resourceType.toUpperCase(),
              style: const TextStyle(fontSize: 10),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          onTap: () => onResultSelected?.call(result),
        );
      },
    );
  }
}
