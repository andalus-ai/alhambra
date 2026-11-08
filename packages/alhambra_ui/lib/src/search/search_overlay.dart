import 'package:alhambra_services/alhambra_services.dart';
import 'package:flutter/material.dart';
import '../theme/spacing.dart';
import 'search_field.dart';
import 'search_results.dart';

/// Modal dialog / overlay for platform-wide search.
class SearchOverlay extends StatefulWidget {
  final SearchService searchService;
  final ValueChanged<SearchResult>? onResultSelected;
  final SearchScope? scope;

  const SearchOverlay({
    super.key,
    required this.searchService,
    this.onResultSelected,
    this.scope,
  });

  static Future<SearchResult?> show(
    BuildContext context, {
    required SearchService searchService,
    SearchScope? scope,
  }) {
    return showDialog<SearchResult>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: SizedBox(
          width: 600,
          height: 480,
          child: SearchOverlay(
            searchService: searchService,
            scope: scope,
            onResultSelected: (result) => Navigator.of(context).pop(result),
          ),
        ),
      ),
    );
  }

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  List<SearchResult> _results = [];
  bool _isLoading = false;

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    final response = await widget.searchService.search(
      SearchQuery(
        text: query,
        scope: widget.scope,
      ),
    );

    if (mounted) {
      setState(() {
        _results = response.results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AlhambraSpacing.md),
      child: Column(
        children: [
          SearchField(
            hintText: 'Search workspaces, documents, resources…',
            onChanged: _performSearch,
          ),
          const SizedBox(height: AlhambraSpacing.md),
          Expanded(
            child: SearchResultsView(
              results: _results,
              isLoading: _isLoading,
              onResultSelected: widget.onResultSelected,
            ),
          ),
        ],
      ),
    );
  }
}
