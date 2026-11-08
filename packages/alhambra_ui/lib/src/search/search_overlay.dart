import 'package:flutter/material.dart';
import '../theme/spacing.dart';
import 'search_field.dart';
import 'search_results.dart';
import 'ui_search_result.dart';

/// Modal dialog / overlay for application-provided search.
class SearchOverlay extends StatefulWidget {
  final UiSearchHandler onSearch;
  final ValueChanged<UiSearchResult>? onResultSelected;
  final String? scopeId;

  const SearchOverlay({
    super.key,
    required this.onSearch,
    this.onResultSelected,
    this.scopeId,
  });

  static Future<UiSearchResult?> show(
    BuildContext context, {
    required UiSearchHandler onSearch,
    String? scopeId,
  }) {
    return showDialog<UiSearchResult>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: SizedBox(
          width: 600,
          height: 480,
          child: SearchOverlay(
            onSearch: onSearch,
            scopeId: scopeId,
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
  List<UiSearchResult> _results = [];
  bool _isLoading = false;
  int _requestGeneration = 0;

  Future<void> _performSearch(String query) async {
    final generation = ++_requestGeneration;
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final results = await widget.onSearch(query, scopeId: widget.scopeId);
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _results = [];
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
